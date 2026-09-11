"""initial schema: users, saved_locations, completed_courses

Revision ID: 0726822181e9
Revises:
Create Date: 2026-09-07
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0726822181e9"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("kakao_id", sa.String(length=64), nullable=False),
        sa.Column("nickname", sa.String(length=80), nullable=False),
        sa.Column("profile_image_url", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("kakao_id", name="uq_users_kakao_id"),
    )
    op.create_index("ix_users_kakao_id", "users", ["kakao_id"])

    op.create_table(
        "saved_locations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("location_id", sa.String(length=100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "location_id", name="uq_saved_location_user_location"),
    )
    op.create_index("ix_saved_locations_user_id", "saved_locations", ["user_id"])

    op.create_table(
        "completed_courses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_id", sa.String(length=100), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "course_id", name="uq_completed_course_user_course"),
    )
    op.create_index("ix_completed_courses_user_id", "completed_courses", ["user_id"])


def downgrade() -> None:
    op.drop_table("completed_courses")
    op.drop_table("saved_locations")
    op.drop_table("users")
