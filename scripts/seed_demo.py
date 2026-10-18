"""Idempotent fixtures for the isolated demo database; uses the production schema."""

import asyncio
import json
import re
import shutil
from datetime import UTC, datetime, timedelta
from pathlib import Path

from sqlalchemy import func, select, text

from scripts.db_safety import ADVISORY_LOCK, SEED_KEY, SEED_VERSION, check_demo_database
from scripts.demo_data import CATEGORIES, TASKS, USERS
from shared.core.config import get_settings
from shared.core.database import session_factory
from shared.models import (
    Application,
    Attachment,
    Category,
    Deliverable,
    DemoMarker,
    Message,
    ModerationAction,
    Notification,
    Order,
    OrderEvent,
    PortfolioCase,
    PortfolioEvidence,
    PrivacyConsent,
    Report,
    Review,
    Task,
    TipSettings,
    User,
)


async def counts(session) -> dict[str, int]:
    return {
        model.__tablename__: await session.scalar(select(func.count()).select_from(model))
        for model in (
            User,
            Category,
            Task,
            Application,
            Order,
            Message,
            Review,
            PortfolioCase,
            Report,
        )
    }


def repair_demo_assets(storage_keys: list[str]) -> None:
    """Keep fixtures readable when the same DB is used from host and containers."""
    upload_dir = get_settings().upload_dir.resolve()
    upload_dir.mkdir(parents=True, exist_ok=True)
    qr_source = Path(__file__).parent / "assets" / "demo-tip-qr.png"
    for key in storage_keys:
        if re.fullmatch(r"demo-tip-qr-[234]\.png", key):
            path = upload_dir / key
            if not path.exists():
                shutil.copyfile(qr_source, path)
        elif match := re.fullmatch(r"demo-result-(\d+)\.txt", key):
            index = int(match.group(1)) - 1
            if index not in range(len(TASKS)):
                continue
            path = upload_dir / key
            if not path.exists():
                title, expected = TASKS[index][3], TASKS[index][5]
                path.write_bytes(result_bytes(title, expected))


def result_bytes(title: str, expected: str) -> bytes:
    return f"FirstCase — демонстрационный результат\n\n{title}\n\n{expected}\n\nЭто безопасный пример файла, загруженного исполнителем в заказ.\n".encode()


async def seed_demo() -> dict[str, int]:
    settings = get_settings()
    async with session_factory() as session, session.begin():
        await session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": ADVISORY_LOCK})
        await check_demo_database(session, require_marker=False)
        marker = await session.get(DemoMarker, SEED_KEY)
        if marker:
            if marker.value != SEED_VERSION:
                raise RuntimeError("A different demo seed exists; run the guarded demo reset first")
            repair_demo_assets(list(await session.scalars(select(Attachment.storage_key))))
            result = await counts(session)
            print(json.dumps({"seed": "already-present", **result}, ensure_ascii=False))
            return result
        now = datetime.now(UTC)
        users = []
        for index, (name, bio, specialization, skills) in enumerate(USERS):
            user = User(
                telegram_id=-(100001 + index),
                username=f"demo_{index + 1}",
                display_name=name,
                bio=bio,
                specialization=specialization,
                skills=skills,
                city="Бишкек",
                role="admin" if index == 5 else "user",
                is_demo=True,
                onboarding_completed=True,
                created_at=now - timedelta(days=30 - index),
            )
            session.add(user)
            users.append(user)
        categories = {}
        for index, (slug, name, _icon) in enumerate(CATEGORIES):
            category = Category(slug=slug, name=name, sort_order=index)
            session.add(category)
            categories[slug] = category
        await session.flush()
        upload_dir = settings.upload_dir.resolve()
        upload_dir.mkdir(parents=True, exist_ok=True)
        qr_source = Path(__file__).parent / "assets" / "demo-tip-qr.png"
        for performer in (2, 3, 4):
            key = f"demo-tip-qr-{performer}.png"
            shutil.copyfile(qr_source, upload_dir / key)
            attachment = Attachment(
                owner_id=users[performer].id,
                filename="demo-tip-qr.png",
                mime_type="image/png",
                size=qr_source.stat().st_size,
                storage_key=key,
            )
            session.add(attachment)
            await session.flush()
            session.add(
                TipSettings(
                    user_id=users[performer].id,
                    payment_method="Демо QR · не предназначен для оплаты",
                    qr_attachment_id=attachment.id,
                    payment_url="https://example.org/firstcase-demo-tips",
                    enabled=True,
                    public_consent=True,
                )
            )
        seeded_tasks = []
        seeded_orders = []
        active_states = [
            "in_progress",
            "in_progress",
            "in_progress",
            "submitted",
            "revision_requested",
            "accepted_pending_review",
            "assigned",
        ]
        for index, (slug, customer, performer, title, brief, expected) in enumerate(TASKS):
            task = Task(
                customer_id=users[customer].id,
                category_id=categories[slug].id,
                title=title,
                description=brief,
                expected_result=expected,
                deadline=now + timedelta(days=3 + index % 9),
                max_revisions=2,
                payment_type="free" if index % 4 == 0 else "tips",
                city="Бишкек",
                status="completed"
                if index < 3
                else "assigned"
                if index < 10
                else "cancelled"
                if index == 10
                else "published",
                created_at=now - timedelta(days=16, hours=index),
            )
            session.add(task)
            await session.flush()
            seeded_tasks.append(task)
            if index == 10:
                continue
            application = Application(
                task_id=task.id,
                performer_id=users[performer].id,
                message=f"Здравствуйте! Мне интересна задача «{title}». Сделаю аккуратно, покажу промежуточный вариант и учту согласованные правки.",
                proposed_deadline=task.deadline,
                status="accepted" if index < 10 else "pending",
            )
            session.add(application)
            if index % 2 == 0:
                alternate = 15 if performer != 15 else 13
                session.add(
                    Application(
                        task_id=task.id,
                        performer_id=users[alternate].id,
                        message="Готов обсудить детали и помочь с первым вариантом. Есть время на этой неделе.",
                        proposed_deadline=task.deadline + timedelta(days=1),
                        status="rejected" if index < 10 else "pending",
                    )
                )
            if index >= 10:
                continue
            status = "completed" if index < 3 else active_states[index - 3]
            order = Order(
                task_id=task.id,
                customer_id=task.customer_id,
                performer_id=users[performer].id,
                status=status,
                max_revisions=2,
                revisions_used=1 if status == "revision_requested" else 0,
                accepted_at=now - timedelta(days=5)
                if index < 3
                else now - timedelta(hours=2)
                if status == "accepted_pending_review"
                else None,
                completed_at=now - timedelta(days=4 - index) if index < 3 else None,
                created_at=now - timedelta(days=12 - index),
            )
            session.add(order)
            await session.flush()
            seeded_orders.append(order)
            session.add(
                OrderEvent(
                    order_id=order.id,
                    actor_id=task.customer_id,
                    type="assigned",
                    details={"demo": True},
                    created_at=order.created_at,
                )
            )
            first_message = Message(
                order_id=order.id,
                author_id=task.customer_id,
                text="Спасибо за отклик! Материалы готовы. Давайте сначала согласуем небольшой черновик.",
                created_at=order.created_at + timedelta(minutes=10),
            )
            session.add(first_message)
            session.add(
                Message(
                    order_id=order.id,
                    author_id=order.performer_id,
                    text="Здравствуйте! Всё посмотрел, задача понятна. Покажу первый вариант, прежде чем готовить финальные файлы.",
                    created_at=order.created_at + timedelta(minutes=25),
                )
            )
            if status in {
                "completed",
                "submitted",
                "revision_requested",
                "accepted_pending_review",
            }:
                key = f"demo-result-{index + 1}.txt"
                content = result_bytes(title, expected)
                (upload_dir / key).write_bytes(content)
                attachment = Attachment(
                    owner_id=order.performer_id,
                    filename=f"Результат-{index + 1}.txt",
                    mime_type="text/plain",
                    size=len(content),
                    storage_key=key,
                    order_id=order.id,
                )
                session.add(attachment)
                await session.flush()
                session.add(
                    Deliverable(
                        order_id=order.id,
                        performer_id=order.performer_id,
                        description="Подготовил финальный вариант и краткую инструкцию. Файл прикреплён к результату.",
                        version=1,
                        attachment_ids=[attachment.id],
                    )
                )
                session.add(
                    OrderEvent(
                        order_id=order.id,
                        actor_id=order.performer_id,
                        type="submitted",
                        details={"version": 1},
                    )
                )
            if status == "revision_requested":
                session.add(
                    OrderEvent(
                        order_id=order.id,
                        actor_id=order.customer_id,
                        type="revision_requested",
                        details={"reason": "Пожалуйста, сделайте заголовок немного крупнее."},
                    )
                )
            if index < 3:
                session.add(
                    Review(
                        order_id=order.id,
                        author_id=order.customer_id,
                        recipient_id=order.performer_id,
                        rating=5 if index != 1 else 4,
                        comment=[
                            "Нурбек внимательно разобрался в задаче, показал промежуточный результат и всё объяснил. Отличный первый совместный проект!",
                            "Диана предложила интересные варианты и аккуратно подготовила исходники. Спасибо за работу!",
                            "Тимур поймал настроение кофейни. Ролик получился живым и очень уютным.",
                        ][index],
                    )
                )
                if index == 0:
                    session.add(
                        Review(
                            order_id=order.id,
                            author_id=order.performer_id,
                            recipient_id=order.customer_id,
                            rating=5,
                            comment="Понятная задача, быстрая обратная связь и уважительное общение.",
                        )
                    )
                session.add(
                    OrderEvent(
                        order_id=order.id,
                        actor_id=order.customer_id,
                        type="completed",
                        details={},
                        created_at=order.completed_at,
                    )
                )
                case = PortfolioCase(
                    owner_id=order.performer_id,
                    order_id=order.id,
                    title=title,
                    description=f"Мой первый подтверждённый проект: {brief}",
                    result=expected,
                    visibility=["anonymous", "public", "private"][index],
                    verified=True,
                    show_customer=index == 1,
                    category_id=task.category_id,
                    completed_at=order.completed_at,
                )
                session.add(case)
                await session.flush()
                if index == 1:
                    await session.flush()
                    session.add(
                        PrivacyConsent(
                            order_id=order.id,
                            customer_id=order.customer_id,
                            allow_identity=True,
                            attachment_ids=[attachment.id],
                            message_ids=[first_message.id],
                        )
                    )
                    session.add(PortfolioEvidence(case_id=case.id, attachment_id=attachment.id))
                    session.add(PortfolioEvidence(case_id=case.id, message_id=first_message.id))
            session.add(
                Notification(
                    user_id=order.performer_id,
                    type="application_accepted",
                    title="Вас выбрали исполнителем",
                    body=f"Заказчик выбрал ваш отклик: {title}",
                    link=f"/orders/{order.id}",
                    delivered_at=now,
                )
            )
        session.add(
            PortfolioCase(
                owner_id=users[6].id,
                title="Иллюстрации городских кофеен",
                description="Личный учебный проект о любимых местах Бишкека.",
                result="Серия из трёх цифровых иллюстраций.",
                visibility="public",
                verified=False,
                category_id=categories["illustration"].id,
            )
        )
        report = Report(
            reporter_id=users[1].id,
            target_type="task",
            target_id=seeded_tasks[22].id,
            reason="other",
            description="Пожалуйста, проверьте описание: кажется, в нём недостаточно деталей о согласованных правках.",
        )
        session.add(report)
        session.add(
            Report(
                reporter_id=users[2].id,
                target_type="order",
                target_id=seeded_orders[7].id,
                reason="agreement_violation",
                description="Нужна помощь с согласованием объёма правок. В переписке есть уточнение требований.",
                status="in_review",
                moderator_comment="Связались с участниками, уточняем первоначальное задание.",
            )
        )
        await session.flush()
        session.add(
            ModerationAction(
                admin_id=users[5].id,
                target_type="report",
                target_id=report.id,
                action="report_opened",
                reason="Жалоба принята в очередь для демонстрации модерации.",
            )
        )
        session.add(
            Notification(
                user_id=users[0].id,
                type="new_application",
                title="Новый отклик на вашу задачу",
                body="Исполнитель предложил помочь с вашим проектом.",
                link=f"/tasks/{seeded_tasks[13].id}",
                delivered_at=now,
            )
        )
        session.add(DemoMarker(key=SEED_KEY, value=SEED_VERSION))
        await session.flush()
        result = await counts(session)
    print(json.dumps({"seed": "created", **result}, ensure_ascii=False))
    return result


if __name__ == "__main__":
    asyncio.run(seed_demo())
