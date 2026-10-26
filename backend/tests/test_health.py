import time
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.main import app

UNREACHABLE_URL = "postgresql+psycopg://postgres:postgres@10.255.255.1:5432/wms_crm_test"


@pytest.fixture
def unavailable_db_client() -> Iterator[TestClient]:
    engine = create_engine(UNREACHABLE_URL, connect_args={"connect_timeout": 3})

    def override_get_db() -> Iterator[Session]:
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    engine.dispose()


def test_health_ok_when_database_available(client: TestClient) -> None:
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "ok"}


def test_health_error_when_database_unavailable(unavailable_db_client: TestClient) -> None:
    started = time.monotonic()
    response = unavailable_db_client.get("/api/health")
    elapsed = time.monotonic() - started

    assert response.status_code == 503
    assert response.json() == {"status": "error", "db": "error"}
    assert elapsed < 5
