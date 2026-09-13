"""Community comments, likes and feed index."""
from alembic import op
import sqlalchemy as sa
revision = "community_detail_v1"
down_revision = "2a46bd2b5158"
branch_labels = None
depends_on = None

def upgrade():
    op.create_table("community_comments", sa.Column("id", sa.Integer(), primary_key=True), sa.Column("post_id", sa.Integer(), sa.ForeignKey("community_posts.id", ondelete="CASCADE"), nullable=False), sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False), sa.Column("body", sa.String(500), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))
    op.create_index("ix_community_comments_post_id", "community_comments", ["post_id"])
    op.create_index("ix_community_comments_user_id", "community_comments", ["user_id"])
    op.create_table("community_likes", sa.Column("post_id", sa.Integer(), sa.ForeignKey("community_posts.id", ondelete="CASCADE"), primary_key=True), sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True))
    op.create_index("ix_community_feed", "community_posts", ["region", "board", "created_at", "id"])

def downgrade():
    op.drop_index("ix_community_feed", table_name="community_posts")
    op.drop_table("community_likes")
    op.drop_table("community_comments")
