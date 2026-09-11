"""add community posts and home region

Revision ID: 8f1a2c9d4b3e
Revises: 0726822181e9
Create Date: 2026-09-11
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "8f1a2c9d4b3e"
down_revision: str | Sequence[str] | None = "0726822181e9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("home_region", sa.String(length=100), nullable=True))

    op.create_table(
        "community_posts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("region", sa.String(length=100), nullable=False),
        sa.Column("location_id", sa.String(length=100), nullable=True),
        sa.Column("photo_path", sa.String(length=300), nullable=False),
        sa.Column("caption", sa.String(length=500), nullable=True),
        sa.Column("memory_year", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_community_posts_user_id", "community_posts", ["user_id"])
    op.create_index("ix_community_posts_region", "community_posts", ["region"])


def downgrade() -> None:
    op.drop_table("community_posts")
    op.drop_column("users", "home_region")
