"""add memory_attributes, connection_requests, direct_messages

Revision ID: memory_matching_v1
Revises: content_blocks_v1
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "memory_matching_v1"
down_revision: str | Sequence[str] | None = "content_blocks_v1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "memory_attributes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column("label", sa.String(length=100), nullable=False),
        sa.Column("place_id", sa.String(length=120), nullable=True),
        sa.Column("start_year", sa.Integer(), nullable=True),
        sa.Column("end_year", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_memory_attributes_user_id", "memory_attributes", ["user_id"])
    op.create_index("ix_memory_attributes_type", "memory_attributes", ["type"])
    op.create_index("ix_memory_attributes_place_id", "memory_attributes", ["place_id"])

    op.create_table(
        "connection_requests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("requester_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("recipient_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("message", sa.String(length=300), nullable=True),
        sa.Column("status", sa.String(length=10), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("requester_id", "recipient_id", name="uq_connection_pair"),
    )
    op.create_index("ix_connection_requests_requester_id", "connection_requests", ["requester_id"])
    op.create_index("ix_connection_requests_recipient_id", "connection_requests", ["recipient_id"])

    op.create_table(
        "direct_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "connection_id", sa.Integer(), sa.ForeignKey("connection_requests.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("sender_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.String(length=1000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_direct_messages_connection_id", "direct_messages", ["connection_id"])


def downgrade() -> None:
    op.drop_index("ix_direct_messages_connection_id", table_name="direct_messages")
    op.drop_table("direct_messages")

    op.drop_index("ix_connection_requests_recipient_id", table_name="connection_requests")
    op.drop_index("ix_connection_requests_requester_id", table_name="connection_requests")
    op.drop_table("connection_requests")

    op.drop_index("ix_memory_attributes_place_id", table_name="memory_attributes")
    op.drop_index("ix_memory_attributes_type", table_name="memory_attributes")
    op.drop_index("ix_memory_attributes_user_id", table_name="memory_attributes")
    op.drop_table("memory_attributes")
