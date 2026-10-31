from pathlib import Path

import pytest

from app.core.config import ENV_FILE, Settings

DEV_URL = "postgresql+psycopg://user:secret@localhost:5432/wms_crm"
TEST_URL = "postgresql+psycopg://user:secret@localhost:5432/wms_crm_test"


def test_env_file_is_in_backend_dir() -> None:
    assert Path(__file__).resolve().parents[1] / ".env" == ENV_FILE


def test_unknown_env_file_variables_are_ignored(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text(f"POSTGRES_USER=someone\nDATABASE_URL={DEV_URL}\n")

    settings = Settings(_env_file=env_file)

    assert settings.database_url == DEV_URL


@pytest.mark.parametrize(("use_test_database", "expected"), [(False, DEV_URL), (True, TEST_URL)])
def test_effective_database_url(use_test_database: bool, expected: str) -> None:
    settings = Settings(
        database_url=DEV_URL, test_database_url=TEST_URL, use_test_database=use_test_database
    )

    assert settings.effective_database_url == expected
