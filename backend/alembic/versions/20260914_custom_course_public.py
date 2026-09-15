"""add is_public to custom_courses

Revision ID: custom_course_public_v1
Revises: regions_trade_v1
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "custom_course_public_v1"
down_revision: str | Sequence[str] | None = "regions_trade_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "custom_courses",
        sa.Column("is_public", sa.Boolean(), nullable=False, server_default="true"),
    )


def downgrade() -> None:
    op.drop_column("custom_courses", "is_public")
