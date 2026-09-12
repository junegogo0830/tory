import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
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
    photo_path: Mapped[str | None] = mapped_column(String(300), nullable=True)
    caption: Mapped[str | None] = mapped_column(String(500), nullable=True)
    memory_year: Mapped[int | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="community_posts")
