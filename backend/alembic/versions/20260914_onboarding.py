"""add age_group/onboarded_at to users for first-login onboarding

Revision ID: onboarding_v1
Revises: custom_signup_v1
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "onboarding_v1"
down_revision: str | Sequence[str] | None = "custom_signup_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("age_group", sa.String(length=10), nullable=True))
    op.add_column("users", sa.Column("onboarded_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "onboarded_at")
    op.drop_column("users", "age_group")
