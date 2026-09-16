"""add last_viewed_course_* to users (홈 "이어보기")

Revision ID: last_viewed_course_v1
Revises: profile_saved_courses_v1
Create Date: 2026-09-16
"""

from alembic import op
import sqlalchemy as sa

revision = "last_viewed_course_v1"
down_revision = "profile_saved_courses_v1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("last_viewed_course_type", sa.String(length=10), nullable=True))
    op.add_column("users", sa.Column("last_viewed_course_id", sa.String(length=50), nullable=True))
    op.add_column("users", sa.Column("last_viewed_course_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "last_viewed_course_at")
    op.drop_column("users", "last_viewed_course_id")
    op.drop_column("users", "last_viewed_course_type")
