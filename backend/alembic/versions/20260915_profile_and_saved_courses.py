"""add users.gender/full_name and saved_courses table

Revision ID: profile_saved_courses_v1
Revises: memory_matching_v1
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "profile_saved_courses_v1"
down_revision: str | Sequence[str] | None = "memory_matching_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("gender", sa.String(length=10), nullable=True))
    op.add_column("users", sa.Column("full_name", sa.String(length=40), nullable=True))

    op.create_table(
        "saved_courses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_type", sa.String(length=10), nullable=False),
        sa.Column("course_id", sa.String(length=50), nullable=False),
        sa.Column("course_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "course_type", "course_id", name="uq_saved_course"),
    )
    op.create_index("ix_saved_courses_user_id", "saved_courses", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_saved_courses_user_id", table_name="saved_courses")
    op.drop_table("saved_courses")
    op.drop_column("users", "full_name")
    op.drop_column("users", "gender")
