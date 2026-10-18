import base64

import pytest

from shared.core.exceptions import DomainError
from shared.core.storage import LocalStorage, safe_filename, validate_bytes


@pytest.mark.parametrize("filename", ["../../secret.txt", r"C:\Windows\secret.txt", "a\nb.txt"])
def test_upload_filename_cannot_be_a_path(filename):
    safe = safe_filename(filename)
    assert safe
    assert "/" not in safe and "\\" not in safe and "\n" not in safe


@pytest.mark.parametrize("key", ["../private", "..", r"sub\file", "/etc/passwd", "C:/Windows/file"])
def test_storage_rejects_path_traversal(tmp_path, key):
    with pytest.raises(DomainError):
        LocalStorage(tmp_path).path(key)


@pytest.mark.parametrize(
    "content,mime",
    [
        (b"<html>not a png</html>", "image/png"),
        (b"not a pdf", "application/pdf"),
        (b"not a zip", "application/zip"),
        (b"binary\x00data", "text/plain"),
        (b"<script>alert(1)</script>", "text/html"),
        (
            base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aU1sAAAAASUVORK5CYII="
            ),
            "image/png",
        ),
    ],
)
def test_file_content_must_match_allowed_mime(content, mime):
    with pytest.raises(DomainError) as error:
        validate_bytes(content, mime)
    assert error.value.status_code == 422


@pytest.mark.asyncio
async def test_storage_roundtrip_uses_server_generated_keys(tmp_path):
    storage = LocalStorage(tmp_path)
    first = await storage.write(b"first real file")
    second = await storage.write(b"second real file")
    assert first != second
    assert storage.path(first).read_bytes() == b"first real file"
    assert storage.path(second).read_bytes() == b"second real file"
