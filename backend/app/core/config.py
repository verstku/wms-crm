from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# backend/.env, resolved from this file so the working directory does not matter.
ENV_FILE = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ENV_FILE, extra="ignore")

    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm"
    test_database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm_test"
    use_test_database: bool = False

    @property
    def effective_database_url(self) -> str:
        """The only place that decides which database the app and Alembic use."""
        if self.use_test_database:
            return self.test_database_url
        return self.database_url


@lru_cache
def get_settings() -> Settings:
    return Settings()
