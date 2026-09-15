"""widen community_posts.caption to 2000 chars

Revision ID: widen_caption_v1
Revises: custom_course_public_v1
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "widen_caption_v1"
down_revision: str | Sequence[str] | None = "custom_course_public_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "community_posts",
        "caption",
        existing_type=sa.String(length=500),
        type_=sa.String(length=2000),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "community_posts",
        "caption",
        existing_type=sa.String(length=2000),
        type_=sa.String(length=500),
        existing_nullable=True,
    )
