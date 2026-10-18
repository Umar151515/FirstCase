"""AI agreements, explicit media roles and saved language preferences.

Revision ID: 9c41d6f2aa70
Revises: 5f2f22dc49e5
"""

import sqlalchemy as sa

from alembic import op

revision = "9c41d6f2aa70"
down_revision = "5f2f22dc49e5"
branch_labels = None
depends_on = None

SYSTEM_TITLES = {
    "Новый отклик на вашу задачу": "new_application",
    "Вас выбрали исполнителем": "performer_selected",
    "Новое сообщение в заказе": "new_message",
    "Исполнитель приступил к работе": "work_started",
    "Работа принята": "work_accepted",
    "Заказчик запросил правки": "revision_requested",
    "Заказ отменён": "order_cancelled",
    "По заказу открыт спор": "dispute_opened",
    "Оставьте отзыв для завершения заказа": "review_required",
    "Исполнитель отправил результат": "work_submitted",
    "Вы получили отзыв": "new_review",
    "Обновление по вашей жалобе": "report_updated",
    "Администратор рассмотрел спор": "dispute_decided",
}


def upgrade() -> None:
    op.add_column("users", sa.Column("language", sa.String(2), server_default="ru", nullable=False))
    op.create_check_constraint("valid_language", "users", "language IN ('ru','ky')")
    op.add_column("users", sa.Column("avatar_attachment_id", sa.Integer(), nullable=True))
    op.create_unique_constraint("uq_users_avatar_attachment_id", "users", ["avatar_attachment_id"])
    op.create_foreign_key(
        "fk_users_avatar_attachment", "users", "attachments", ["avatar_attachment_id"], ["id"]
    )
    for table in ("tasks", "orders"):
        op.add_column(
            table,
            sa.Column("ai_policy", sa.String(16), server_default="ai_allowed", nullable=False),
        )
        op.create_check_constraint(
            "valid_ai_policy", table, "ai_policy IN ('no_ai','consultation','ai_allowed')"
        )
    for table in ("deliverables", "portfolio_cases"):
        op.add_column(
            table, sa.Column("ai_usage", sa.String(16), server_default="no_ai", nullable=False)
        )
        op.add_column(
            table, sa.Column("ai_disclosure", sa.String(2000), server_default="", nullable=False)
        )
        op.create_check_constraint(
            "valid_ai_usage", table, "ai_usage IN ('no_ai','consultation','ai_assisted')"
        )
    for table in ("tasks", "portfolio_cases"):
        op.add_column(table, sa.Column("cover_attachment_id", sa.Integer(), nullable=True))
        op.create_foreign_key(
            f"fk_{table}_cover_attachment", table, "attachments", ["cover_attachment_id"], ["id"]
        )
    # Preserve old messages and user content. Only known system titles become keys.
    connection = op.get_bind()
    for title, key in SYSTEM_TITLES.items():
        connection.execute(
            sa.text("UPDATE notifications SET title=:key WHERE title=:title"),
            {"title": title, "key": key},
        )


def downgrade() -> None:
    connection = op.get_bind()
    for title, key in SYSTEM_TITLES.items():
        connection.execute(
            sa.text("UPDATE notifications SET title=:title WHERE title=:key"),
            {"title": title, "key": key},
        )
    for table in ("tasks", "portfolio_cases"):
        op.drop_constraint(f"fk_{table}_cover_attachment", table, type_="foreignkey")
        op.drop_column(table, "cover_attachment_id")
    for table in ("deliverables", "portfolio_cases"):
        op.drop_constraint(op.f(f"ck_{table}_valid_ai_usage"), table, type_="check")
        op.drop_column(table, "ai_disclosure")
        op.drop_column(table, "ai_usage")
    for table in ("tasks", "orders"):
        op.drop_constraint(op.f(f"ck_{table}_valid_ai_policy"), table, type_="check")
        op.drop_column(table, "ai_policy")
    op.drop_constraint("fk_users_avatar_attachment", "users", type_="foreignkey")
    op.drop_constraint("uq_users_avatar_attachment_id", "users", type_="unique")
    op.drop_column("users", "avatar_attachment_id")
    op.drop_constraint(op.f("ck_users_valid_language"), "users", type_="check")
    op.drop_column("users", "language")
