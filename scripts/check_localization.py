"""Check the RU/KY message contract and prevent UI strings outside ARB files.

Run from any directory with Python 3. No third-party packages are required.
User-authored content is rendered directly and never passed through a dictionary.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = ROOT / "frontend/lib/l10n"
CYRILLIC = re.compile(r"[А-Яа-яЁёӨөҮүҢң]")
PLACEHOLDER = re.compile(r"\{([a-zA-Z][a-zA-Z0-9_]*)(?:\s*,|\})")


def messages(data: dict) -> dict[str, str]:
    return {key: value for key, value in data.items() if not key.startswith("@")}


def check() -> list[str]:
    errors: list[str] = []
    catalogs = {
        code: json.loads((CATALOGS / f"app_{code}.arb").read_text(encoding="utf-8"))
        for code in ("ru", "ky")
    }
    russian, kyrgyz = (messages(catalogs[code]) for code in ("ru", "ky"))
    for key in sorted(russian.keys() ^ kyrgyz.keys()):
        errors.append(f"catalog key mismatch: {key}")
    for key in russian.keys() & kyrgyz.keys():
        if not re.fullmatch(r"[a-z][a-zA-Z0-9]*", key):
            errors.append(f"message key must be semantic lowerCamelCase: {key}")
        for locale, value in (("ru", russian[key]), ("ky", kyrgyz[key])):
            if not isinstance(value, str) or not value.strip():
                errors.append(f"empty message: {locale}.{key}")
            if "??" in value or "\ufffd" in value:
                errors.append(f"damaged Unicode translation: {locale}.{key}")
        expected = set(catalogs["ru"].get(f"@{key}", {}).get("placeholders", {}))
        for locale, value in (("ru", russian[key]), ("ky", kyrgyz[key])):
            if PLACEHOLDER.findall(value) and set(PLACEHOLDER.findall(value)) != expected:
                errors.append(f"placeholder mismatch: {locale}.{key}")
            if expected and not expected.issubset(PLACEHOLDER.findall(value)):
                errors.append(f"missing placeholder: {locale}.{key}")
    # Generated locale classes and ARB files are the only UI translation sources.
    # Ignore comment-only lines; all other Cyrillic in app Dart files is an error.
    for path in (ROOT / "frontend/lib").rglob("*.dart"):
        if "l10n" in path.parts or path.name.endswith(".g.dart"):
            continue
        in_comment = False
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.lstrip()
            if stripped.startswith("/*"):
                in_comment = True
            if not in_comment and not stripped.startswith("//") and CYRILLIC.search(line):
                errors.append(f"{path.relative_to(ROOT)}:{number}: text must use context.l10n")
            if "*/" in stripped:
                in_comment = False
    return errors


if __name__ == "__main__":
    problems = check()
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print("RU/KY catalogs, placeholders and UI string boundaries are valid.")
