"""add community board and title

Revision ID: 2a46bd2b5158
Revises: 8f1a2c9d4b3e
Create Date: 2026-09-12
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "2a46bd2b5158"
down_revision: str | Sequence[str] | None = "8f1a2c9d4b3e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "community_posts",
        sa.Column("board", sa.String(length=20), nullable=False, server_default="free"),
    )
    op.add_column("community_posts", sa.Column("title", sa.String(length=120), nullable=True))
    # 자유/주민/관광정보 게시판은 사진이 필수가 아니다 — 추억 게시판만 원래 사진 중심.
    op.alter_column("community_posts", "photo_path", existing_type=sa.String(length=300), nullable=True)
    op.create_index("ix_community_posts_board", "community_posts", ["board"])


def downgrade() -> None:
    op.drop_index("ix_community_posts_board", table_name="community_posts")
    op.alter_column("community_posts", "photo_path", existing_type=sa.String(length=300), nullable=False)
    op.drop_column("community_posts", "title")
    op.drop_column("community_posts", "board")
