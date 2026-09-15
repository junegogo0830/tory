"""add reveal_at for timecapsule board

Revision ID: timecapsule_v1
Revises: photos_replies_v1
Create Date: 2026-09-13
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "timecapsule_v1"
down_revision: str | Sequence[str] | None = "photos_replies_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("community_posts", sa.Column("reveal_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("community_posts", "reveal_at")
