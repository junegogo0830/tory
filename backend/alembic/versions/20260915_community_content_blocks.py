"""add content_blocks (JSON string) to community_posts

Revision ID: content_blocks_v1
Revises: widen_caption_v1
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "content_blocks_v1"
down_revision: str | Sequence[str] | None = "widen_caption_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("community_posts", sa.Column("content_blocks", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("community_posts", "content_blocks")
