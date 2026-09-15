"""add region_memberships table, price/trade_status on community_posts

Revision ID: regions_trade_v1
Revises: onboarding_v1
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "regions_trade_v1"
down_revision: str | Sequence[str] | None = "onboarding_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "region_memberships",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("region", sa.String(length=100), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "region", name="uq_region_membership_user_region"),
    )
    op.create_index("ix_region_memberships_user_id", "region_memberships", ["user_id"])
    op.create_index("ix_region_memberships_region", "region_memberships", ["region"])

    op.add_column("community_posts", sa.Column("price", sa.Integer(), nullable=True))
    op.add_column("community_posts", sa.Column("trade_status", sa.String(length=10), nullable=True))

    # 이미 home_region이 있는 기존 유저는 그 지역에 가입한 걸로 소급 처리한다 —
    # 안 그러면 이 마이그레이션 이후 갑자기 "가입한 지역 없음"이 돼 토글이 비게 된다.
    op.execute(
        """
        INSERT INTO region_memberships (user_id, region, joined_at)
        SELECT id, home_region, now() FROM users
        WHERE home_region IS NOT NULL
        ON CONFLICT (user_id, region) DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_column("community_posts", "trade_status")
    op.drop_column("community_posts", "price")
    op.drop_index("ix_region_memberships_region", table_name="region_memberships")
    op.drop_index("ix_region_memberships_user_id", table_name="region_memberships")
    op.drop_table("region_memberships")
