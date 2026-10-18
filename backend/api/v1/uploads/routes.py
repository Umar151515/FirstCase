from fastapi import APIRouter, File, UploadFile
from fastapi.responses import FileResponse

from backend.api.dependencies import Config, CurrentUser, OptionalUser, Session
from shared.core.exceptions import DomainError
from shared.features.uploads.schemas import AttachmentOut
from shared.features.uploads.services import UploadService

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.get("/{identifier}/metadata", response_model=AttachmentOut)
async def metadata(identifier: int, user: OptionalUser, session: Session, settings: Config):
    service = UploadService(session, settings)
    return service.view(await service.readable(identifier, user.id if user else None))


@router.post("", response_model=AttachmentOut, status_code=201)
async def upload(user: CurrentUser, session: Session, settings: Config, file: UploadFile = File()):
    data = await file.read(settings.max_upload_size_mb * 1024 * 1024 + 1)
    if len(data) > settings.max_upload_size_mb * 1024 * 1024:
        raise DomainError("file_too_large", 413, "file_too_large")
    service = UploadService(session, settings)
    item = await service.create(
        user.id, data, file.filename, file.content_type or "application/octet-stream"
    )
    return service.view(item)


@router.get("/{identifier}", response_class=FileResponse)
async def download(identifier: int, user: OptionalUser, session: Session, settings: Config):
    file, path = await UploadService(session, settings).download(
        identifier, user.id if user else None
    )
    return FileResponse(
        path,
        filename=file.filename,
        media_type=file.mime_type,
        content_disposition_type="attachment",
        headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"},
    )
