"""Report/block moderation, notifications, saved generated courses."""
from alembic import op
import sqlalchemy as sa
revision = "moderation_v1"
down_revision = "community_detail_v1"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("users", sa.Column("notify_on_comment", sa.Boolean(), nullable=False, server_default="true"))
    op.add_column("users", sa.Column("notify_on_like", sa.Boolean(), nullable=False, server_default="true"))
    op.add_column("community_posts", sa.Column("hidden", sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("community_comments", sa.Column("hidden", sa.Boolean(), nullable=False, server_default="false"))

    op.create_table(
        "community_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reporter_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_type", sa.String(10), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(200), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("reporter_id", "target_type", "target_id", name="uq_report_reporter_target"),
    )
    op.create_index("ix_community_reports_reporter_id", "community_reports", ["reporter_id"])
    op.create_index("ix_community_reports_target_id", "community_reports", ["target_id"])

    op.create_table(
        "user_blocks",
        sa.Column("blocker_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("blocked_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_nickname", sa.String(80), nullable=False),
        sa.Column("post_id", sa.Integer(), sa.ForeignKey("community_posts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("post_title", sa.String(120), nullable=True),
        sa.Column("comment_id", sa.Integer(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_feed", "notifications", ["user_id", "created_at", "id"])

    op.create_table(
        "user_courses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("course_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_user_courses_user_id", "user_courses", ["user_id"])

def downgrade():
    op.drop_index("ix_user_courses_user_id", table_name="user_courses")
    op.drop_table("user_courses")
    op.drop_index("ix_notifications_feed", table_name="notifications")
    op.drop_index("ix_notifications_user_id", table_name="notifications")
    op.drop_table("notifications")
    op.drop_table("user_blocks")
    op.drop_index("ix_community_reports_target_id", table_name="community_reports")
    op.drop_index("ix_community_reports_reporter_id", table_name="community_reports")
    op.drop_table("community_reports")
    op.drop_column("community_comments", "hidden")
    op.drop_column("community_posts", "hidden")
    op.drop_column("users", "notify_on_like")
    op.drop_column("users", "notify_on_comment")
