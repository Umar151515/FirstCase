from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from scripts.db_safety import PURPOSE_VALUE, check_demo_database


def session_stub(*, database="firstcase_demo", marker=None, users=0, real_users=0):
    return SimpleNamespace(
        scalar=AsyncMock(
            side_effect=[database, users, real_users] if marker is None else [database, real_users]
        ),
        get=AsyncMock(return_value=marker),
        add=lambda value: None,
        flush=AsyncMock(),
    )


@pytest.mark.parametrize("mode", ["production", "invalid"])
async def test_demo_guard_rejects_non_demo_mode_before_database_access(monkeypatch, mode):
    monkeypatch.setattr("scripts.db_safety.get_settings", lambda: SimpleNamespace(app_mode=mode))
    session = session_stub()
    with pytest.raises(RuntimeError, match="forbidden"):
        await check_demo_database(session, require_marker=True)
    session.scalar.assert_not_awaited()


@pytest.mark.parametrize("database", ["firstcase_production", "firstcase_test", "postgres"])
async def test_demo_guard_rejects_wrong_database(monkeypatch, database):
    monkeypatch.setattr("scripts.db_safety.get_settings", lambda: SimpleNamespace(app_mode="demo"))
    with pytest.raises(RuntimeError, match="isolated database"):
        await check_demo_database(session_stub(database=database), require_marker=True)


async def test_reset_requires_database_ownership_marker(monkeypatch):
    monkeypatch.setattr("scripts.db_safety.get_settings", lambda: SimpleNamespace(app_mode="demo"))
    with pytest.raises(RuntimeError, match="no demo ownership marker"):
        await check_demo_database(session_stub(), require_marker=True)


async def test_seed_never_claims_an_existing_database(monkeypatch):
    monkeypatch.setattr("scripts.db_safety.get_settings", lambda: SimpleNamespace(app_mode="demo"))
    with pytest.raises(RuntimeError, match="already contains users"):
        await check_demo_database(session_stub(users=2), require_marker=False)


async def test_reset_rejects_real_identities_even_with_marker(monkeypatch):
    monkeypatch.setattr("scripts.db_safety.get_settings", lambda: SimpleNamespace(app_mode="demo"))
    marker = SimpleNamespace(value=PURPOSE_VALUE)
    with pytest.raises(RuntimeError, match="non-demo identities"):
        await check_demo_database(session_stub(marker=marker, real_users=1), require_marker=True)


async def test_guard_rejects_another_purpose_marker(monkeypatch):
    monkeypatch.setattr("scripts.db_safety.get_settings", lambda: SimpleNamespace(app_mode="demo"))
    marker = SimpleNamespace(value="production")
    with pytest.raises(RuntimeError, match="purpose marker does not match"):
        await check_demo_database(session_stub(marker=marker), require_marker=True)
