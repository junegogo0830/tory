"""add custom_courses, custom_course_votes, custom_course_comments

Revision ID: custom_course_v1
Revises: timecapsule_v1
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "custom_course_v1"
down_revision: str | Sequence[str] | None = "timecapsule_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "custom_courses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(length=60), nullable=False),
        sa.Column("category", sa.String(length=20), nullable=False),
        sa.Column("description", sa.String(length=300), nullable=True),
        sa.Column("places_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_custom_courses_user_id", "custom_courses", ["user_id"])
    op.create_index("ix_custom_courses_category", "custom_courses", ["category"])

    op.create_table(
        "custom_course_votes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("custom_courses.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("value", sa.Integer(), nullable=False),
        sa.UniqueConstraint("course_id", "user_id", name="uq_custom_course_vote_user"),
    )
    op.create_index("ix_custom_course_votes_course_id", "custom_course_votes", ["course_id"])
    op.create_index("ix_custom_course_votes_user_id", "custom_course_votes", ["user_id"])

    op.create_table(
        "custom_course_comments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("custom_courses.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.String(length=300), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_custom_course_comments_course_id", "custom_course_comments", ["course_id"])
    op.create_index("ix_custom_course_comments_user_id", "custom_course_comments", ["user_id"])


def downgrade() -> None:
    op.drop_table("custom_course_comments")
    op.drop_table("custom_course_votes")
    op.drop_table("custom_courses")
