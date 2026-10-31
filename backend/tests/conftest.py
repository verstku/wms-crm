from collections.abc import Iterator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine, make_url, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.db import get_db
from app.main import app

BACKEND_DIR = Path(__file__).resolve().parents[1]


def exit_unless_test_database(database: str) -> None:
    # The schema of the test database is dropped, so never touch a database that is not a test one.
    if not database.endswith("_test"):
        pytest.exit(
            f"TEST_DATABASE_URL must point to a database whose name ends with '_test', "
            f"got '{database}'",
            returncode=1,
        )


@pytest.fixture(scope="session")
def test_engine() -> Iterator[Engine]:
    url = get_settings().test_database_url
    # First guard, before any connection: the database name in the URL path.
    exit_unless_test_database(make_url(url).database or "")

    engine = create_engine(url)
    with engine.begin() as connection:
        # Second guard: query parameters such as ?dbname= can override the path,
        # so check the database we are actually connected to.
        exit_unless_test_database(
            connection.execute(text("SELECT current_database()")).scalar_one()
        )
        connection.execute(text("DROP SCHEMA public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))

    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.attributes["database_url"] = url
    command.upgrade(cfg, "head")

    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine: Engine) -> Iterator[Session]:
    # Everything a test writes, even after session.commit(), is rolled back afterwards.
    connection = test_engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection, join_transaction_mode="create_savepoint")

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session: Session) -> Iterator[TestClient]:
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
