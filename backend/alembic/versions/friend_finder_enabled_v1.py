"""add friend finder visibility setting"""
from alembic import op
import sqlalchemy as sa
revision = "friend_finder_enabled_v1"
down_revision = "last_viewed_course_v1"
branch_labels = None
depends_on = None
def upgrade() -> None:
    op.add_column("users", sa.Column("friend_finder_enabled", sa.Boolean(), server_default="true", nullable=False))
def downgrade() -> None:
    op.drop_column("users", "friend_finder_enabled")
