import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    kakao_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    nickname: Mapped[str] = mapped_column(String(80))
    profile_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # 커뮤니티 탭에서 GPS/검색으로 설정한 "내 동네" (예: "경기 수원시 영통구"). 한 사용자당
    # 하나만 두는 단순한 모델 — 다대다 커뮤니티 가입까지는 이번 스코프에 넣지 않는다.
    home_region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # 알림 설정 — 둘 다 기본 켜짐. 끄면 그 종류의 알림 레코드 자체를 안 만든다.
    notify_on_comment: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    notify_on_like: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    saved_locations: Mapped[list["SavedLocation"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    completed_courses: Mapped[list["CompletedCourse"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    community_posts: Mapped[list["CommunityPost"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class SavedLocation(Base):
    __tablename__ = "saved_locations"
    __table_args__ = (UniqueConstraint("user_id", "location_id", name="uq_saved_location_user_location"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    # location_id는 TourAPI/큐레이션 장소의 id (예: "suncheon-jeonpo"). 별도 locations 테이블 없이
    # tourapi 서비스가 소스 오브 트루스이므로 문자열 참조만 저장한다.
    location_id: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="saved_locations")


class CompletedCourse(Base):
    __tablename__ = "completed_courses"
    __table_args__ = (UniqueConstraint("user_id", "course_id", name="uq_completed_course_user_course"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(String(100))
    completed_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="completed_courses")


class CommunityPost(Base):
    """사용자가 직접 올리는 "그 시절 추억" 사진 게시물.

    TourAPI/큐레이션처럼 외부에서 실시간으로 불러오는 게 아니라 우리 DB가
    소스 오브 트루스인 첫 콘텐츠 타입이라, saved_locations와 달리 사진 파일
    자체를 관리해야 한다(photo_path, community.py 서비스가 저장/서빙).
    """

    __tablename__ = "community_posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    # "경기 수원시 영통구" 같은 지역명 — Kakao 역지오코딩 결과 그대로 저장해 피드 필터링에 쓴다.
    region: Mapped[str] = mapped_column(String(100), index=True)
    # 게시판 구분: free(자유)/memory(추억)/resident(주민)/info(관광정보). 지역별로 4개
    # 게시판이 별도로 운영되는 구조라 region+board 조합이 사실상의 "게시판" 단위다.
    board: Mapped[str] = mapped_column(String(20), index=True, default="free")
    title: Mapped[str | None] = mapped_column(String(120), nullable=True)
    # compare_screen(특정 장소 상세)에서 올렸으면 그 장소 id, 커뮤니티 탭에서 바로 올렸으면 None.
    location_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # uploads/community/ 기준 상대경로 (예: "3f2a.../photo.jpg"). 자유/주민/관광정보
    # 게시판은 사진 없이 글만 올릴 수 있어 nullable — 추억 게시판만 사진이 사실상 필수.
    # 대표(첫 번째) 사진 — 목록/카드 미리보기는 이 한 장만 쓴다. 실제 전체 사진은
    # community_post_photos에 있다(여러 장 지원). 이 컬럼은 하위 호환용 캐시.
    photo_path: Mapped[str | None] = mapped_column(String(300), nullable=True)
    caption: Mapped[str | None] = mapped_column(String(500), nullable=True)
    memory_year: Mapped[int | None] = mapped_column(nullable=True)
    # 신고 누적으로 자동 숨김 처리된 글. 숨겨지면 목록/상세 모두에서 제외한다.
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="community_posts")
    photos: Mapped[list["CommunityPostPhoto"]] = relationship(
        back_populates="post", cascade="all, delete-orphan", order_by="CommunityPostPhoto.position"
    )


class CommunityPostPhoto(Base):
    """게시글 사진 여러 장. 순서를 유지해야 해서 position을 따로 둔다."""

    __tablename__ = "community_post_photos"

    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("community_posts.id", ondelete="CASCADE"), index=True)
    photo_path: Mapped[str] = mapped_column(String(300))
    position: Mapped[int] = mapped_column(default=0)

    post: Mapped[CommunityPost] = relationship(back_populates="photos")


class CommunityComment(Base):
    __tablename__ = "community_comments"
    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("community_posts.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    # 답글이면 원 댓글(항상 최상위 댓글) id. 답글의 답글은 만들지 않고 같은 최상위
    # 댓글에 묶어서 1단계 스레드만 유지한다(services/community.py의 add_comment 참고).
    parent_id: Mapped[int | None] = mapped_column(
        ForeignKey("community_comments.id", ondelete="CASCADE"), nullable=True
    )
    body: Mapped[str] = mapped_column(String(500))
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CommunityLike(Base):
    __tablename__ = "community_likes"
    post_id: Mapped[int] = mapped_column(ForeignKey("community_posts.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)


class CommunityReport(Base):
    """게시글/댓글 신고. 관리자 화면은 없어서, 같은 대상이 일정 횟수 이상 신고되면
    자동으로 hidden 처리하는 경량 모더레이션으로 대신한다."""

    __tablename__ = "community_reports"
    __table_args__ = (
        UniqueConstraint("reporter_id", "target_type", "target_id", name="uq_report_reporter_target"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    target_type: Mapped[str] = mapped_column(String(10))  # "post" | "comment"
    target_id: Mapped[int] = mapped_column(index=True)
    reason: Mapped[str] = mapped_column(String(200))
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UserBlock(Base):
    """차단한 사용자의 글/댓글은 피드에서 조용히 제외한다(상대에게 알리지 않음)."""

    __tablename__ = "user_blocks"

    blocker_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    blocked_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Notification(Base):
    """내 글에 달린 댓글/좋아요 알림. actor_nickname/post_title은 원본이 지워져도
    알림 문구가 깨지지 않게 생성 시점 값을 그대로 복사해둔 스냅샷이다."""

    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(20))  # "comment" | "like"
    actor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    actor_nickname: Mapped[str] = mapped_column(String(80))
    post_id: Mapped[int] = mapped_column(ForeignKey("community_posts.id", ondelete="CASCADE"))
    post_title: Mapped[str | None] = mapped_column(String(120), nullable=True)
    comment_id: Mapped[int | None] = mapped_column(nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UserCourse(Base):
    """사용자가 생성한 맞춤 코스의 영구 저장본. LLM 생성 결과 캐시(Redis, 30일)와
    별개로 "내가 만든 코스" 목록은 DB에 스냅샷 JSON으로 무기한 보관한다."""

    __tablename__ = "user_courses"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(String(120))
    course_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
