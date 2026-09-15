import json

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.models import CommunityPost, ConnectionRequest, CustomCourse, MemoryAttribute, User, UserBlock
from ..models.memory import (
    MemoryAttributeCreateRequest,
    MemoryAttributeResponse,
    MemoryMatchResponse,
    MemoryProfileResponse,
    MemorySearchFilter,
)

# 규칙 기반 가중치 — 학교/동네는 라벨이 같고 연도가 겹쳐야 점수를 주고, 장소는
# (연도 무관하게) 같은 place_id를 등록/방문했으면 점수를 준다.
_SCHOOL_WEIGHT = 40
_REGION_WEIGHT = 20
_PLACE_WEIGHT = 15


def _years_overlap(a_start: int | None, a_end: int | None, b_start: int | None, b_end: int | None) -> bool:
    """None은 열린 구간(과거/미래로 무한)으로 취급한다."""
    lo_a, hi_a = a_start if a_start is not None else -10_000, a_end if a_end is not None else 10_000
    lo_b, hi_b = b_start if b_start is not None else -10_000, b_end if b_end is not None else 10_000
    return lo_a <= hi_b and lo_b <= hi_a


def _period_label(start: int | None, end: int | None) -> str:
    if start and end:
        return f"{start}~{end}"
    if start:
        return f"{start}~"
    if end:
        return f"~{end}"
    return ""


def _object_particle(word: str) -> str:
    """마지막 글자 받침 유무로 을/를을 고른다 — "중앙역을", "분식집을" 같은 자연스러운 문구용."""
    if not word:
        return "를"
    code = ord(word[-1]) - 0xAC00
    if 0 <= code < 11172:
        return "을" if code % 28 != 0 else "를"
    return "를"


def _canonical_place_id(source: str, place_id: str) -> str:
    """CustomCoursePlaceInput의 place_id를 community_posts.location_id/
    saved_locations.location_id와 같은 네임스페이스로 정규화한다. tour 출처는
    이미 "tour-{contentId}" 형식이라 그대로 두고, kakao 출처는 접두사가 없어서
    "kakao-{id}"로 맞춰줘야 다른 테이블과 비교가 된다."""
    if source == "kakao" and not place_id.startswith("kakao-"):
        return f"kakao-{place_id}"
    return place_id


async def _find_connection(db: AsyncSession, user_a: int, user_b: int) -> ConnectionRequest | None:
    return await db.scalar(
        select(ConnectionRequest).where(
            ((ConnectionRequest.requester_id == user_a) & (ConnectionRequest.recipient_id == user_b))
            | ((ConnectionRequest.requester_id == user_b) & (ConnectionRequest.recipient_id == user_a))
        )
    )


class MemoryProfileService:
    """"추억 조건"(학교/동네/자주 간 장소 + 시기) 프로필과, 그걸 기준으로 한
    친구 매칭·코스 겹침 계산."""

    async def add_attribute(self, db: AsyncSession, user: User, body: MemoryAttributeCreateRequest) -> MemoryAttributeResponse:
        attribute = MemoryAttribute(
            user_id=user.id,
            type=body.type,
            label=body.label,
            place_id=body.place_id if body.type == "place" else None,
            start_year=body.start_year,
            end_year=body.end_year,
        )
        db.add(attribute)
        await db.commit()
        await db.refresh(attribute)
        return MemoryAttributeResponse.model_validate(attribute, from_attributes=True)

    async def list_attributes(self, db: AsyncSession, user_id: int) -> list[MemoryAttributeResponse]:
        rows = await db.execute(
            select(MemoryAttribute).where(MemoryAttribute.user_id == user_id).order_by(MemoryAttribute.created_at)
        )
        return [MemoryAttributeResponse.model_validate(a, from_attributes=True) for a in rows.scalars().all()]

    async def delete_attribute(self, db: AsyncSession, user: User, attribute_id: int) -> None:
        attribute = await db.get(MemoryAttribute, attribute_id)
        if attribute is None or attribute.user_id != user.id:
            raise HTTPException(404, "삭제되었거나 없는 조건이에요")
        await db.delete(attribute)
        await db.commit()

    async def get_profile(self, db: AsyncSession, viewer: User | None, target_user_id: int) -> MemoryProfileResponse:
        target = await db.get(User, target_user_id)
        if target is None:
            raise HTTPException(404, "존재하지 않는 사용자예요")

        attributes = await self.list_attributes(db, target_user_id)
        course_count = await db.scalar(
            select(func.count())
            .select_from(CustomCourse)
            .where(CustomCourse.user_id == target_user_id, CustomCourse.is_public.is_(True))
        )
        memory_post_count = await db.scalar(
            select(func.count())
            .select_from(CommunityPost)
            .where(
                CommunityPost.user_id == target_user_id,
                CommunityPost.board == "memory",
                CommunityPost.hidden.is_(False),
            )
        )

        is_mine = viewer is not None and viewer.id == target_user_id
        connection_status: str = "none"
        connection_id: int | None = None
        if viewer is not None and not is_mine:
            connection = await _find_connection(db, viewer.id, target_user_id)
            if connection is not None:
                connection_id = connection.id
                if connection.status == "accepted":
                    connection_status = "accepted"
                elif connection.status == "pending":
                    connection_status = "pending_sent" if connection.requester_id == viewer.id else "pending_received"

        return MemoryProfileResponse(
            user_id=target.id,
            nickname=target.nickname,
            profile_image_url=target.profile_image_url,
            attributes=attributes,
            course_count=course_count or 0,
            memory_post_count=memory_post_count or 0,
            is_mine=is_mine,
            connection_status=connection_status,
            connection_id=connection_id,
        )

    @staticmethod
    def _score_overlap(
        filters: list[MemorySearchFilter], candidates: list[MemoryAttribute]
    ) -> tuple[int, list[str]]:
        score = 0
        reasons: list[str] = []
        for condition in filters:
            for candidate in candidates:
                if candidate.type != condition.type:
                    continue
                if condition.type == "place":
                    if condition.place_id and candidate.place_id == condition.place_id:
                        score += _PLACE_WEIGHT
                        reasons.append(f"{candidate.label}{_object_particle(candidate.label)} 추억 장소로 등록")
                        break
                elif candidate.label == condition.label and _years_overlap(
                    condition.start_year, condition.end_year, candidate.start_year, candidate.end_year
                ):
                    period = _period_label(candidate.start_year, candidate.end_year)
                    if condition.type == "school":
                        score += _SCHOOL_WEIGHT
                        reasons.append(f"{candidate.label} {period}".strip())
                    else:
                        score += _REGION_WEIGHT
                        reasons.append(f"같은 동네 · {candidate.label} {period}".strip())
                    break
        return score, reasons

    async def search_matches(
        self, db: AsyncSession, user: User, filters: list[MemorySearchFilter]
    ) -> list[MemoryMatchResponse]:
        blocked = {
            row[0]
            for row in (
                await db.execute(select(UserBlock.blocked_id).where(UserBlock.blocker_id == user.id))
            ).all()
        }
        rows = await db.execute(select(MemoryAttribute).where(MemoryAttribute.user_id != user.id))
        by_user: dict[int, list[MemoryAttribute]] = {}
        for attribute in rows.scalars().all():
            if attribute.user_id in blocked:
                continue
            by_user.setdefault(attribute.user_id, []).append(attribute)

        scored: list[tuple[int, int, list[str]]] = []
        for candidate_id, attributes in by_user.items():
            score, reasons = self._score_overlap(filters, attributes)
            if score > 0:
                scored.append((candidate_id, score, reasons))
        if not scored:
            return []

        users = await db.execute(select(User).where(User.id.in_([s[0] for s in scored])))
        user_map = {u.id: u for u in users.scalars().all()}
        results = [
            MemoryMatchResponse(
                user_id=uid, nickname=user_map[uid].nickname, profile_image_url=user_map[uid].profile_image_url,
                score=score, reasons=reasons,
            )
            for uid, score, reasons in scored
            if uid in user_map
        ]
        results.sort(key=lambda r: r.score, reverse=True)
        return results

    async def overlap_for_course(self, db: AsyncSession, course: CustomCourse) -> list[MemoryMatchResponse]:
        places = json.loads(course.places_json)
        place_ids: set[str] = set()
        place_names: dict[str, str] = {}
        for place in places:
            canonical = _canonical_place_id(place["source"], place["place_id"])
            place_ids.add(canonical)
            place_names[canonical] = place["name"]
        if not place_ids:
            return []

        scores: dict[int, int] = {}
        reasons: dict[int, list[str]] = {}

        # (a) 코스가 방문하는 장소를 "자주 간 장소" 추억 속성으로 등록한 유저.
        place_attr_rows = await db.execute(
            select(MemoryAttribute).where(
                MemoryAttribute.type == "place",
                MemoryAttribute.place_id.in_(place_ids),
                MemoryAttribute.user_id != course.user_id,
            )
        )
        for attribute in place_attr_rows.scalars().all():
            name = place_names.get(attribute.place_id, attribute.label)
            scores[attribute.user_id] = scores.get(attribute.user_id, 0) + _PLACE_WEIGHT
            reasons.setdefault(attribute.user_id, []).append(f"{name}{_object_particle(name)} 추억 장소로 등록")

        # (b) 코스가 방문하는 장소에 커뮤니티 글을 남긴 유저.
        post_rows = await db.execute(
            select(CommunityPost.user_id, CommunityPost.location_id).where(
                CommunityPost.location_id.in_(place_ids),
                CommunityPost.user_id != course.user_id,
                CommunityPost.hidden.is_(False),
            )
        )
        seen_post_place: set[tuple[int, str]] = set()
        for user_id, location_id in post_rows.all():
            key = (user_id, location_id)
            if key in seen_post_place:
                continue
            seen_post_place.add(key)
            name = place_names.get(location_id, "이 장소")
            scores[user_id] = scores.get(user_id, 0) + _PLACE_WEIGHT
            reasons.setdefault(user_id, []).append(f"같은 {name}에 추억 글 작성")

        # (c) 코스 작성자 본인의 학교/동네 속성과 겹치는 다른 유저.
        creator_attrs = [a for a in await self.list_attributes(db, course.user_id) if a.type in ("school", "region")]
        if creator_attrs:
            candidate_rows = await db.execute(
                select(MemoryAttribute).where(
                    MemoryAttribute.type.in_(("school", "region")),
                    MemoryAttribute.user_id != course.user_id,
                )
            )
            for candidate in candidate_rows.scalars().all():
                for creator_attr in creator_attrs:
                    if candidate.type != creator_attr.type or candidate.label != creator_attr.label:
                        continue
                    if not _years_overlap(
                        candidate.start_year, candidate.end_year, creator_attr.start_year, creator_attr.end_year
                    ):
                        continue
                    weight = _SCHOOL_WEIGHT if candidate.type == "school" else _REGION_WEIGHT
                    period = _period_label(candidate.start_year, candidate.end_year)
                    reason = (
                        f"{candidate.label} {period}".strip()
                        if candidate.type == "school"
                        else f"같은 동네 · {candidate.label} {period}".strip()
                    )
                    scores[candidate.user_id] = scores.get(candidate.user_id, 0) + weight
                    reasons.setdefault(candidate.user_id, []).append(reason)
                    break  # 작성자 속성 하나당 한 번만 반영 — 중복 가점 방지.

        if not scores:
            return []

        users = await db.execute(select(User).where(User.id.in_(scores.keys())))
        user_map = {u.id: u for u in users.scalars().all()}
        results = [
            MemoryMatchResponse(
                user_id=uid, nickname=user_map[uid].nickname, profile_image_url=user_map[uid].profile_image_url,
                score=score, reasons=reasons[uid],
            )
            for uid, score in scores.items()
            if uid in user_map
        ]
        results.sort(key=lambda r: r.score, reverse=True)
        return results
