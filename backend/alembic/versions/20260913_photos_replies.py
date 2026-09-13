"""Multiple post photos, comment replies."""
from alembic import op
import sqlalchemy as sa
revision = "photos_replies_v1"
down_revision = "moderation_v1"
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        "community_post_photos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("post_id", sa.Integer(), sa.ForeignKey("community_posts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("photo_path", sa.String(300), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_community_post_photos_post_id", "community_post_photos", ["post_id"])

    op.add_column(
        "community_comments",
        sa.Column(
            "parent_id", sa.Integer(), sa.ForeignKey("community_comments.id", ondelete="CASCADE"), nullable=True
        ),
    )
    op.create_index("ix_community_comments_parent_id", "community_comments", ["parent_id"])

def downgrade():
    op.drop_index("ix_community_comments_parent_id", table_name="community_comments")
    op.drop_column("community_comments", "parent_id")
    op.drop_index("ix_community_post_photos_post_id", table_name="community_post_photos")
    op.drop_table("community_post_photos")
