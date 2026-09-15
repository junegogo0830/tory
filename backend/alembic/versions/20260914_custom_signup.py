"""add username/password/phone signup fields to users, phone_verifications table

Revision ID: custom_signup_v1
Revises: custom_course_v1
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "custom_signup_v1"
down_revision: str | Sequence[str] | None = "custom_course_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("users", "kakao_id", existing_type=sa.String(length=64), nullable=True)

    op.add_column("users", sa.Column("username", sa.String(length=30), nullable=True))
    op.add_column("users", sa.Column("password_hash", sa.String(length=255), nullable=True))
    op.add_column("users", sa.Column("phone_number", sa.String(length=20), nullable=True))
    op.add_column("users", sa.Column("terms_agreed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("privacy_agreed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column(
        "users",
        sa.Column("marketing_agreed", sa.Boolean(), nullable=False, server_default="false"),
    )
    # mapped_column(unique=True, index=True)와 똑같이 "유니크 인덱스 하나"로 만든다
    # (별도 유니크 제약 + 평범한 인덱스를 따로 두면 같은 목적의 인덱스가 중복된다).
    op.create_index("ix_users_username", "users", ["username"], unique=True)
    op.create_index("ix_users_phone_number", "users", ["phone_number"], unique=True)

    op.create_table(
        "phone_verifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("phone_number", sa.String(length=20), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_phone_verifications_phone_number", "phone_verifications", ["phone_number"])


def downgrade() -> None:
    op.drop_table("phone_verifications")

    op.drop_index("ix_users_phone_number", table_name="users")
    op.drop_index("ix_users_username", table_name="users")
    op.drop_column("users", "marketing_agreed")
    op.drop_column("users", "privacy_agreed_at")
    op.drop_column("users", "terms_agreed_at")
    op.drop_column("users", "phone_number")
    op.drop_column("users", "password_hash")
    op.drop_column("users", "username")

    op.alter_column("users", "kakao_id", existing_type=sa.String(length=64), nullable=False)
