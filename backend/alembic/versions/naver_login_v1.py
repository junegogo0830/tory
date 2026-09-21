"""add naver login id"""
from alembic import op
import sqlalchemy as sa
revision = "naver_login_v1"
down_revision = "community_engagement_v1"
branch_labels = None
depends_on = None
def upgrade() -> None:
    op.add_column("users", sa.Column("naver_id", sa.String(length=64), nullable=True))
    op.create_index("ix_users_naver_id", "users", ["naver_id"], unique=True)
def downgrade() -> None:
    op.drop_index("ix_users_naver_id", table_name="users")
    op.drop_column("users", "naver_id")
