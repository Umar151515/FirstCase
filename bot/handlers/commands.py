from html import escape

from aiogram import Router
from aiogram.filters import Command, CommandStart, ExceptionTypeFilter
from aiogram.types import ErrorEvent, Message

from bot.keyboards.webapp import open_app
from shared.core.config import Settings
from shared.core.exceptions import DomainError
from shared.features.auth.services import AuthService
from shared.features.tasks.services import TaskService
from shared.features.users.services import UserService

router = Router(name="firstcase-commands")


@router.error(ExceptionTypeFilter(DomainError))
async def domain_error(event: ErrorEvent) -> None:
    if event.update.message:
        await event.update.message.answer(event.exception.message, parse_mode=None)


@router.message(CommandStart())
async def start(message: Message, settings: Settings, auth_service: AuthService) -> None:
    if message.from_user is None or message.chat.type != "private":
        await message.answer("Откройте личный чат с ботом, чтобы войти в FirstCase.")
        return
    user = await auth_service.upsert_telegram(message.from_user.model_dump())
    # Persist the Telegram identity before making the external send request.
    await auth_service.session.commit()
    await message.answer(
        f"Привет, {escape(user.display_name)}!\n\n"
        "<b>Первый заказ. Первый кейс. Реальная репутация.</b>\n\n"
        "Найдите небольшую задачу, получите опыт и создайте подтверждённое портфолио. "
        "Все задачи бесплатные или с добровольными чаевыми.",
        reply_markup=open_app(settings.public_webapp_url),
    )


@router.message(Command("help"))
async def help_command(message: Message, settings: Settings) -> None:
    if message.chat.type != "private":
        await message.answer("Откройте личный чат с ботом, чтобы войти в FirstCase.")
        return
    await message.answer(
        "/start — открыть FirstCase\n/profile — ваш профиль\n/tasks — найти задачу\n\n"
        "Заказчик создаёт задачу и выбирает исполнителя. После сдачи результата "
        "заказчик принимает работу и оставляет отзыв. Исполнитель сам решает, "
        "добавить ли подтверждённый кейс в портфолио.\n\n"
        "Приватность бесплатна. FirstCase не принимает и не подтверждает платежи. "
        "Жалобу можно отправить со страницы задачи или рабочего пространства.",
        reply_markup=open_app(settings.public_webapp_url),
    )


@router.message(Command("profile"))
async def profile(message: Message, settings: Settings, user_service: UserService) -> None:
    if message.from_user is None or message.chat.type != "private":
        return
    user = await user_service.get_by_telegram(message.from_user.id)
    if user is None:
        await message.answer("Сначала отправьте /start, чтобы создать профиль.")
        return
    await message.answer(
        f"<b>{escape(user.display_name)}</b>\n"
        f"{escape(user.specialization or 'Специализация пока не указана')}\n"
        f"{escape(user.city)}\n\n{escape(user.bio or 'Расскажите о себе в профиле.')}",
        reply_markup=open_app(settings.public_webapp_url, "/profile", "Мой профиль"),
    )


@router.message(Command("tasks"))
async def tasks(message: Message, settings: Settings, task_service: TaskService) -> None:
    if message.chat.type != "private":
        await message.answer("Откройте личный чат с ботом, чтобы найти задачу.")
        return
    items, total = await task_service.catalog(status="published", limit=5)
    lines = [f"<b>Открытые задачи: {total}</b>"]
    lines.extend(f"• {escape(task.title)}" for task in items)
    if not items:
        lines.append("Новых задач пока нет. Можно создать свою в приложении.")
    await message.answer(
        "\n\n".join(lines),
        reply_markup=open_app(settings.public_webapp_url, "/tasks", "Найти заказ"),
    )
