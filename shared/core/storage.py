import asyncio
import io
import re
import warnings
import zipfile
from pathlib import Path, PureWindowsPath
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from shared.core.exceptions import DomainError, missing

ALLOWED_MIMES = {
    "image/png",
    "image/jpeg",
    "image/webp",
    "application/pdf",
    "text/plain",
    "application/zip",
}


def safe_filename(value: str | None) -> str:
    name = PureWindowsPath((value or "file").replace("/", "\\")).name
    name = "".join(c for c in name if c.isprintable() and c not in '<>:"|?*').strip(" .")
    return name[:180] or "file"


def validate_bytes(data: bytes, mime_type: str):
    if mime_type not in ALLOWED_MIMES:
        raise DomainError("unsupported_file", 422, "invalid_file")
    try:
        if mime_type.startswith("image/"):
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(io.BytesIO(data)) as picture:
                    actual = {"PNG": "image/png", "JPEG": "image/jpeg", "WEBP": "image/webp"}.get(
                        picture.format
                    )
                    if actual != mime_type or picture.width * picture.height > 25_000_000:
                        raise ValueError("Invalid image")
                    picture.verify()
        elif mime_type == "application/pdf" and not data.startswith(b"%PDF-"):
            raise ValueError("Invalid PDF")
        elif mime_type == "application/zip":
            if not zipfile.is_zipfile(io.BytesIO(data)):
                raise ValueError("Invalid ZIP")
        elif mime_type == "text/plain":
            if b"\x00" in data:
                raise ValueError("Invalid text")
            data.decode("utf-8")
    except (
        ValueError,
        OSError,
        SyntaxError,
        UnidentifiedImageError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ) as exc:
        raise DomainError("file_type_mismatch", 422, "invalid_file") from exc


def sanitize_image(data: bytes, mime_type: str) -> bytes:
    """Strip EXIF/GPS and embedded metadata before an upload can become public."""
    with Image.open(io.BytesIO(data)) as original:
        oriented = ImageOps.exif_transpose(original)
        mode = (
            "RGBA"
            if mime_type != "image/jpeg"
            and ("A" in oriented.getbands() or "transparency" in oriented.info)
            else "RGB"
        )
        picture = Image.new(mode, oriented.size)
        picture.paste(oriented.convert(mode))
        output = io.BytesIO()
        picture.save(
            output,
            format={"image/png": "PNG", "image/jpeg": "JPEG", "image/webp": "WEBP"}[mime_type],
        )
        return output.getvalue()


class LocalStorage:
    def __init__(self, root: Path):
        self.root = root.resolve()

    def path(self, key: str) -> Path:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,79}", key) or ".." in key:
            raise missing()
        path = (self.root / key).resolve()
        if not path.is_relative_to(self.root):
            raise missing()
        return path

    async def write(self, data: bytes) -> str:
        key = uuid4().hex
        await asyncio.to_thread(self.root.mkdir, parents=True, exist_ok=True)
        await asyncio.to_thread(self.path(key).write_bytes, data)
        return key
