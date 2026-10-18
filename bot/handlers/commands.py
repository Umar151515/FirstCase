from html import escape

from aiogram import Router
from aiogram.filters import Command, CommandStart, ExceptionTypeFilter
from aiogram.types import ErrorEvent, Message

from bot.keyboards.webapp import open_app
from shared.core.config import Settings
from shared.core.exceptions import DomainError
from shared.core.i18n import translate
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
        await message.answer(translate("bot.private_chat"))
        return
    user = await auth_service.upsert_telegram(message.from_user.model_dump())
    await auth_service.session.commit()
    await message.answer(
        translate("bot.start", user.language, name=escape(user.display_name)),
        reply_markup=open_app(settings.public_webapp_url),
    )


@router.message(Command("help"))
async def help_command(message: Message, settings: Settings) -> None:
    if message.chat.type != "private":
        await message.answer(translate("bot.private_chat"))
        return
    await message.answer(translate("bot.help"), reply_markup=open_app(settings.public_webapp_url))


@router.message(Command("profile"))
async def profile(message: Message, settings: Settings, user_service: UserService) -> None:
    if message.from_user is None or message.chat.type != "private":
        return
    user = await user_service.get_by_telegram(message.from_user.id)
    if user is None:
        await message.answer(translate("bot.start_required"))
        return
    await message.answer(
        f"<b>{escape(user.display_name)}</b>\n"
        f"{escape(user.specialization or translate('bot.specialization_empty'))}\n"
        f"{escape(user.city)}\n\n{escape(user.bio or translate('bot.bio_empty'))}",
        reply_markup=open_app(settings.public_webapp_url, "/profile", translate("bot.profile")),
    )


@router.message(Command("tasks"))
async def tasks(message: Message, settings: Settings, task_service: TaskService) -> None:
    if message.chat.type != "private":
        await message.answer(translate("bot.private_chat"))
        return
    items, total = await task_service.catalog(status="published", limit=5)
    lines = [f"<b>{translate('bot.tasks_count', total=total)}</b>"]
    lines.extend(f"• {escape(task.title)}" for task in items)
    if not items:
        lines.append(translate("bot.tasks_empty"))
    await message.answer(
        "\n\n".join(lines),
        reply_markup=open_app(settings.public_webapp_url, "/tasks", translate("bot.tasks")),
    )
