"""Private, consent-based Telegram chat invitations.

Revision ID: b2d7e841c930
Revises: 9c41d6f2aa70
"""

import sqlalchemy as sa

from alembic import op

revision = "b2d7e841c930"
down_revision = "9c41d6f2aa70"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "telegram_invites",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id"), nullable=False),
        sa.Column("requested_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("requester_username", sa.String(32), nullable=False),
        sa.Column("recipient_username", sa.String(32), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "status IN ('pending','accepted','declined','cancelled')", name="valid_status"
        ),
    )
    op.create_index("ix_telegram_invites_order_id", "telegram_invites", ["order_id"])


def downgrade() -> None:
    op.drop_index("ix_telegram_invites_order_id", table_name="telegram_invites")
    op.drop_table("telegram_invites")
