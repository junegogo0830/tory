"""add view_count and categories to community_posts (게시판 카테고리/조회수)

Revision ID: community_engagement_v1
Revises: friend_finder_enabled_v1
Create Date: 2026-09-18
"""

from alembic import op
import sqlalchemy as sa

revision = "community_engagement_v1"
down_revision = "friend_finder_enabled_v1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "community_posts",
        sa.Column("view_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column("community_posts", sa.Column("categories", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("community_posts", "categories")
    op.drop_column("community_posts", "view_count")
