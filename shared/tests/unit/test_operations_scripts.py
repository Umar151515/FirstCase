import json

import pytest

from scripts import check_localization


@pytest.mark.parametrize("bad_value", [None, 12, ["unexpected"], {"unexpected": "object"}])
def test_localization_reports_invalid_message_values_without_crashing(
    tmp_path, monkeypatch, bad_value
):
    catalogs = tmp_path / "frontend" / "lib" / "l10n"
    catalogs.mkdir(parents=True)
    (catalogs / "app_ru.arb").write_text(
        json.dumps({"greeting": "Hello {name}", "@greeting": {"placeholders": {"name": {}}}}),
        encoding="utf-8",
    )
    (catalogs / "app_ky.arb").write_text(json.dumps({"greeting": bad_value}), encoding="utf-8")
    monkeypatch.setattr(check_localization, "ROOT", tmp_path)
    monkeypatch.setattr(check_localization, "CATALOGS", catalogs)
    assert check_localization.check() == ["empty message: ky.greeting"]
