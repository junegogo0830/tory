import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    # 카카오 로그인 사용자만 채워진다 — 자체 회원가입 사용자는 None(NULL은 유니크
    # 인덱스에서 서로 충돌하지 않으므로 여러 명이 동시에 None이어도 괜찮다).
    kakao_id: Mapped[str | None] = mapped_column(String(64), unique=True, index=True, nullable=True)
    # 자체 회원가입 사용자만 채워진다 — 카카오 사용자는 None.
    username: Mapped[str | None] = mapped_column(String(30), unique=True, index=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # 자체 회원가입 시 본인확인 인증을 거친 번호. 카카오 사용자는 None일 수 있다.
    phone_number: Mapped[str | None] = mapped_column(String(20), unique=True, index=True, nullable=True)
    terms_agreed_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    privacy_agreed_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    marketing_agreed: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    # 첫 로그인 온보딩(연령대/거주지/살았던 곳 입력) — 완료했든 건너뛰었든 한 번
    # 지나가면 채워진다. null이면 아직 온보딩 화면을 안 본 사용자라는 뜻이라
    # 다음 로그인 때 다시 보여준다(AppShell 참고).
    age_group: Mapped[str | None] = mapped_column(String(10), nullable=True)
    onboarded_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    nickname: Mapped[str] = mapped_column(String(80))
    profile_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # 커뮤니티 탭에서 GPS/검색으로 설정한 "내 동네" (예: "경기 수원시 영통구"). 한 사용자당
    # 하나만 두는 단순한 모델 — 다대다 커뮤니티 가입까지는 이번 스코프에 넣지 않는다.
    home_region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # 프로필 "정보 수정"에서 입력하는 부가 정보 — 전부 선택 입력.
    gender: Mapped[str | None] = mapped_column(String(10), nullable=True)
    # 닉네임(표시용)과 별개인 실명.
    full_name: Mapped[str | None] = mapped_column(String(40), nullable=True)
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


class PhoneVerification(Base):
    """자체 회원가입의 휴대폰 본인확인 인증번호 — 성공하면 짧은 유효기간의
    phone_verified 토큰(core/security.py)을 발급해 회원가입 요청에 실어 보내게
    한다. 유저 테이블과는 독립적이라(가입 전 단계) FK가 없다."""

    __tablename__ = "phone_verifications"

    id: Mapped[int] = mapped_column(primary_key=True)
    phone_number: Mapped[str] = mapped_column(String(20), index=True)
    # 평문 저장하지 않는다 — DB가 유출돼도 인증번호를 그대로 재사용 못 하게.
    code_hash: Mapped[str] = mapped_column(String(64))
    attempt_count: Mapped[int] = mapped_column(default=0, server_default="0")
    expires_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True))
    verified_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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
    caption: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    # 블로그 스타일 글쓰기 — 텍스트/사진 블록을 순서대로 저장한 JSON 문자열
    # (places_json과 같은 패턴). None이면 옛 글(캡션+사진 평면 구조)로 취급한다.
    content_blocks: Mapped[str | None] = mapped_column(Text, nullable=True)
    memory_year: Mapped[int | None] = mapped_column(nullable=True)
    # 주민 게시판(board="resident") 전용 중고거래 필드 — 다른 게시판은 항상 None.
    # price가 None이면 "무료 나눔" 취급(화면에서 가격 대신 "나눔"으로 보여준다).
    price: Mapped[int | None] = mapped_column(nullable=True)
    trade_status: Mapped[str | None] = mapped_column(String(10), nullable=True)
    # 타임캡슐 게시판(board="timecapsule") 전용 — 이 시각이 지나기 전엔 목록/상세
    # 응답에서 제목·내용·사진을 가리고 "봉인됨"만 보여준다. 다른 게시판은 항상 None.
    reveal_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # 신고 누적으로 자동 숨김 처리된 글. 숨겨지면 목록/상세 모두에서 제외한다.
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="community_posts")
    photos: Mapped[list["CommunityPostPhoto"]] = relationship(
        back_populates="post", cascade="all, delete-orphan", order_by="CommunityPostPhoto.position"
    )


class RegionMembership(Base):
    """사용자가 "가입"한 동네 커뮤니티 — 살았던 곳이 여러 곳일 수 있어 User당
    여러 행을 가질 수 있다(다대다). User.home_region은 이 중 "지금 보고 있는"
    동네 하나를 가리키는 포인터일 뿐이고, 실제 가입 이력은 전부 여기 남는다 —
    커뮤니티 탭의 지역 토글이 이 목록을 그대로 보여준다."""

    __tablename__ = "region_memberships"
    __table_args__ = (UniqueConstraint("user_id", "region", name="uq_region_membership_user_region"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    region: Mapped[str] = mapped_column(String(100), index=True)
    joined_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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


class CustomCourse(Base):
    """사용자가 직접 장소를 검색해 조합한 코스를 커뮤니티에 공유한 것.
    LLM 생성/큐레이션 코스(UserCourse)와 달리 우리 DB가 소스 오브 트루스다."""

    __tablename__ = "custom_courses"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(60))
    category: Mapped[str] = mapped_column(String(20), index=True)
    description: Mapped[str | None] = mapped_column(String(300), nullable=True)
    # 장소 목록은 관계형 테이블 없이 JSON 스냅샷으로 저장한다 — UserCourse.course_json과
    # 같은 패턴. 순서가 있는 목록이고 항상 코스 단위 전체로만 읽으므로 정규화 이득이 없다.
    places_json: Mapped[str] = mapped_column(Text)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship()
    votes: Mapped[list["CustomCourseVote"]] = relationship(
        back_populates="course", cascade="all, delete-orphan"
    )
    comments: Mapped[list["CustomCourseComment"]] = relationship(
        back_populates="course", cascade="all, delete-orphan"
    )


class CustomCourseVote(Base):
    """추천(1)/비추천(-1). 사용자당 코스 하나에 최대 한 표만 — 다시 누르면
    서비스 레이어가 지우거나(0) 값을 바꿔서(upsert) 반영한다."""

    __tablename__ = "custom_course_votes"
    __table_args__ = (UniqueConstraint("course_id", "user_id", name="uq_custom_course_vote_user"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("custom_courses.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    value: Mapped[int] = mapped_column()  # 1 | -1

    course: Mapped[CustomCourse] = relationship(back_populates="votes")


class CustomCourseComment(Base):
    __tablename__ = "custom_course_comments"

    id: Mapped[int] = mapped_column(primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("custom_courses.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    body: Mapped[str] = mapped_column(String(300))
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    course: Mapped[CustomCourse] = relationship(back_populates="comments")


class UserCourse(Base):
    """사용자가 생성한 맞춤 코스의 영구 저장본. LLM 생성 결과 캐시(Redis, 30일)와
    별개로 "내가 만든 코스" 목록은 DB에 스냅샷 JSON으로 무기한 보관한다."""

    __tablename__ = "user_courses"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(String(120))
    course_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MemoryAttribute(Base):
    """"추억 조건" 하나 — 학교/동네/자주 간 장소 중 하나와, 그 시기(연도 범위).
    한 사용자가 여러 개 가질 수 있다(다닌 학교 여러 곳, 살았던 동네 여러 곳 등).
    "친구 찾기"의 매칭 점수 계산과 커스텀 코스의 "추억이 겹치는 사람" 계산이
    둘 다 이 테이블 하나를 기준으로 삼는다."""

    __tablename__ = "memory_attributes"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(20), index=True)  # "region" | "school" | "place"
    label: Mapped[str] = mapped_column(String(100))
    # type="place"일 때만 채워진다 — location_id 네임스페이스로 정규화된 값
    # (예: "tour-123", "kakao-456") 이라 커뮤니티 글 위치 태그/코스 방문지와 직접 비교할 수 있다.
    place_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    start_year: Mapped[int | None] = mapped_column(nullable=True)
    end_year: Mapped[int | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ConnectionRequest(Base):
    """"연결 요청" — 수락돼야(status="accepted") 서로 메시지를 주고받을 수 있다.
    한 쌍(requester, recipient)에 하나만 존재 — 재요청/철회 대신 기존 행을
    재사용하는 게 아니라 그냥 pending 상태에서 중복 생성을 막는다."""

    __tablename__ = "connection_requests"
    __table_args__ = (UniqueConstraint("requester_id", "recipient_id", name="uq_connection_pair"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    requester_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    recipient_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    message: Mapped[str | None] = mapped_column(String(300), nullable=True)
    status: Mapped[str] = mapped_column(String(10), default="pending", server_default="pending")  # pending|accepted|declined
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    responded_at: Mapped[datetime.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class DirectMessage(Base):
    """연결(accepted)된 두 사용자 사이의 메시지. 실시간 소켓이 아니라 REST
    폴링(화면 진입 시 조회 + 전송 후 재조회)으로 주고받는다."""

    __tablename__ = "direct_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    connection_id: Mapped[int] = mapped_column(ForeignKey("connection_requests.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    body: Mapped[str] = mapped_column(String(1000))
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SavedCourse(Base):
    """코스 북마크 — "완주"(CompletedCourse)와 달리 아직 안 가본 코스도 나중에
    보려고 찜해두는 용도. AI 생성 코스는 캐시가 30일 뒤 만료될 수 있어(UserCourse가
    스냅샷을 영구 보관하는 것과 같은 이유) 저장 시점에 course_json으로 그대로
    떠 둔다 — 커스텀 코스는 우리 DB가 소스 오브 트루스라 id만 있으면 된다."""

    __tablename__ = "saved_courses"
    __table_args__ = (UniqueConstraint("user_id", "course_type", "course_id", name="uq_saved_course"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_type: Mapped[str] = mapped_column(String(10))  # "generated" | "custom"
    course_id: Mapped[str] = mapped_column(String(50))
    course_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
