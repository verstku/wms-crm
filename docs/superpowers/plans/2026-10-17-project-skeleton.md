# Скелет проекта «Система управления складом» — план реализации

> **Для агентов-исполнителей:** обязательный навык — superpowers:executing-plans (subagent-driven — только по просьбе
> владельца, см. CLAUDE.md). Шаги отмечаются чекбоксами (`- [ ]`).

**Цель:** фундамент проекта без бизнес-логики: БД в Docker, бэкенд FastAPI с `GET /api/health`, фронтенд Next.js
со статусом бэкенда, единый `scripts/check.sh`, e2e-тесты, CI и документация.

**Архитектура:** PostgreSQL 18 в Docker с двумя базами — `wms_crm` и `wms_crm_test`. Бэкенд — синхронный FastAPI
и SQLAlchemy; адрес БД выбирается в одном месте (`effective_database_url`); схема API выгружается в
`frontend/openapi.json` без запуска сервера. Фронтенд — Next.js App Router: браузер обращается к `/api/...`,
Next.js проксирует запрос на бэкенд (rewrites); типы клиента генерируются из OpenAPI.

**Технологии:** Python 3.13, uv, FastAPI, SQLAlchemy 2.1, Alembic, Pydantic 2, pytest; Node 24, Next.js 16.4,
next-intl, shadcn/ui (Base UI), openapi-fetch, Vitest, Playwright; Docker Compose; GitHub Actions.

**Спека:** `docs/superpowers/specs/2026-10-16-project-skeleton-design.md`. Исполнитель читает её вместе с планом;
ссылки вида «спека 4.2» — на её разделы.

## Глобальные ограничения

- Python 3.13 (`.python-version`), пакеты бэкенда — только `uv add` / `uv add --dev`. Node 24 (`.nvmrc`),
  пакеты фронтенда — `npm install`.
- Версии проверены 2026-10-17: fastapi 0.143, sqlalchemy 2.1, alembic 1.20, pydantic 2.14, pydantic-settings 2.16,
  psycopg 3.3, uvicorn 0.54, pytest 9.1, ruff 0.17, mypy 2.4, httpx2 2.13; next 16.4.2, next-intl 4.14,
  openapi-fetch 0.17, openapi-typescript 7.13, vitest 5.0, @playwright/test 1.64, prettier 3.9,
  eslint-config-prettier 10.1, shadcn 4.22. Если при установке мажорная версия окажется новее — остановиться и спросить.
  Фактически установленные версии бэкенда — см. отклонение в задаче 2, шаге 1.
- Зачем нужна каждая зависимость — спека 4.1 (бэкенд) и таблица 5.1 (фронтенд); подъём `@types/node` объяснён
  в задаче 6.
- Порты: разработка — бэкенд 8000 (`wms_crm`), фронт 3000; e2e — бэкенд 8001 (`wms_crm_test`), фронт 3001
  (`.next-e2e`); БД — `127.0.0.1:5432`.
- Код, имена, комментарии в коде, коммиты — на английском. README, CLAUDE.md, ROADMAP — на русском. Тексты
  интерфейса — только в `frontend/messages/{ru,en}.json`; ожидаемые тексты в e2e — по-русски прямо в тесте.
- Строгий TDD: сначала падающий тест и его запуск, потом код. **Исключение (решение владельца):** инфраструктурные
  `backend/app/core/db.py`, `backend/app/models/base.py` и `frontend/src/lib/api/client.ts` пишутся без своих
  тестов — их проверяют команды в задачах 3 и 9 и тесты задач 4 и 10.
- pytest и e2e одновременно не запускать — обе используют `wms_crm_test`.
- API библиотек сверять с Context7; для Next.js — с `frontend/node_modules/next/dist/docs/`.
- Коммит — только в конце этапа, после проверки владельцем и его подтверждения (спека 10). Без `Co-Authored-By`.
  После коммита — остановка до команды владельца на следующий этап.
- Отметки чекбоксов в этом плане коммитятся вместе с коммитом этапа. Во всех проверках `git status` изменение
  файла плана `docs/superpowers/plans/2026-10-17-project-skeleton.md` допустимо (`M ` или ` M`).
- npm 12 пишет «install-scripts … blocked» (`unrs-resolver`, `@swc/core`, `@parcel/watcher`) — это нормально:
  на пробе lint, сборка и тесты работают без этих скриптов. Скрипты не одобрять. `npm audit fix --force`
  не запускать: он откатывает `shadcn` до 1.0.0 (предупреждения `npm audit` — в зависимостях CLI shadcn).

## На что смотреть при ревью (Review Focus)

1. В `backend/.env` лишняя переменная (например, скопированный `POSTGRES_USER`) → бэкенд, Alembic и pytest
   запускаются как обычно. Тест: `test_config.py::test_unknown_env_file_variables_are_ignored` (задача 2).
2. `USE_TEST_DATABASE=true` → используется `wms_crm_test`, а не рабочая БД (иначе e2e пишет в `wms_crm`).
   Тест: `test_config.py::test_effective_database_url` (задача 2). Что `engine` и `alembic/env.py` действительно
   берут этот адрес — задача 3, шаг 6 и задача 4, шаг 5.
3. `TEST_DATABASE_URL` указывает на БД, имя которой не оканчивается на `_test` → pytest останавливается
   с понятной ошибкой до `DROP SCHEMA`. Проверка: задача 4, шаг 6.
4. После `npm run test:e2e` файл `next-env.d.ts` ссылается на удалённую папку `.next-e2e` (его переписывает
   `next build`) → `npm run typecheck` и `npm run lint` всё равно зелёные: `next typegen` пересоздаёт файл.
   Проверка: задача 10, шаг 7.
5. Сгенерированного файла нет (`schema.d.ts` удалён) → проверка 10 в `check.sh` — FAIL с подсказкой, остальные
   проверки выполняются, временная папка удалена. Проверка: задача 11, шаг 5.

---

## Этап 1. Бэкенд и БД

### Задача 1: PostgreSQL в Docker

**Файлы:**
- Создать: `docker-compose.yml`, `docker/postgres/init/01-create-databases.sql`, `.env.example`

**Интерфейсы:**
- Даёт: сервис `db` на `127.0.0.1:5432`; пользователь и пароль по умолчанию — `postgres`/`postgres`; базы
  `wms_crm` и `wms_crm_test`.

- [x] **Шаг 1: `docker-compose.yml`** — только сервис `db`, значения из спеки 3.1. Том — `pgdata:/var/lib/postgresql`
  (объявить в `volumes:` верхнего уровня), init-папка — `./docker/postgres/init:/docker-entrypoint-initdb.d:ro`.
  Healthcheck — ровно так:

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h localhost -U $${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      start_period: 30s
      retries: 10
```

- [x] **Шаг 2: init-скрипт** `docker/postgres/init/01-create-databases.sql` — две строки `CREATE DATABASE` из спеки 3.2.

- [x] **Шаг 3: корневой `.env.example`** — `POSTGRES_USER=postgres`, `POSTGRES_PASSWORD=postgres` и комментарий
  (по-английски): при смене пароля поменять его в корневом `.env` и в обоих адресах в `backend/.env`, затем
  `docker compose down -v`.

- [x] **Шаг 4: проверка.**

Run (корень): `docker compose up -d --wait && docker compose ps`
Expected: код 0, `db` — `healthy`.

Run: `docker compose exec db psql -U postgres -lqt`
Expected: в выводе есть `wms_crm` и `wms_crm_test`.

Run: `git check-ignore --no-index .env.example`
Expected: пустой вывод.

Если том уже существовал и баз в нём нет, нужен `docker compose down -v && docker compose up -d --wait` — сначала
спросить владельца: `down -v` удаляет данные.

### Задача 2: Проект бэкенда и настройки

**Файлы:**
- Создать (командами uv): `backend/pyproject.toml`, `backend/uv.lock`, `backend/.python-version`
- Создать: `backend/.env.example`, `backend/app/__init__.py`, `backend/app/core/__init__.py` (пустые),
  `backend/app/core/config.py`
- Тест: `backend/tests/test_config.py`

**Интерфейсы:**
- Даёт: `app.core.config.ENV_FILE: Path`; `class Settings(BaseSettings)` — поля `database_url: str`,
  `test_database_url: str`, `use_test_database: bool = False`, свойство `effective_database_url -> str`;
  `get_settings() -> Settings` под `@lru_cache`.

- [x] **Шаг 1: создать проект** (из корня; зачем каждая зависимость — спека 4.1):

```bash
uv init --bare --name wms-crm-backend --python 3.13 backend
cd backend && uv python pin 3.13
uv add fastapi "uvicorn[standard]" sqlalchemy "psycopg[binary]" alembic pydantic pydantic-settings
uv add --dev pytest ruff mypy httpx2
```

Expected: в `backend/` только `pyproject.toml`, `uv.lock`, `.python-version` и `.venv/` (последний — в `.gitignore`).

Отклонение (2026-10-26, одобрено владельцем): установлены более свежие версии, чем проверенные 2026-10-17, —
fastapi 0.162.0 (было 0.143), starlette 1.10.0 (было 1.8), httpx2 2.16.0 (было 2.13); остальные пакеты совпадают
с планом с точностью до патч-версии. Мажорных скачков нет. Changelog FastAPI 0.143.1–0.162.0 и Starlette 1.9–1.10
просмотрен: ломающие изменения касаются форм, `**extra` в параметрах, `root_path` и `openapi_prefix` — в скелете
не используются; TestClient с httpx2, `responses=`, `include_router(prefix=)`, `dependency_overrides` и `app.openapi()`
не затронуты, новых предупреждений об устаревании для них нет.

- [x] **Шаг 2: настройки инструментов в `pyproject.toml`** — спека 4.7, по секциям:

```toml
[tool.ruff]
line-length = 100
target-version = "py313"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM"]

[tool.ruff.lint.isort]
known-third-party = ["alembic"]

[tool.mypy]
strict = true
plugins = ["pydantic.mypy"]

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
```

  `select` — именно в `[tool.ruff.lint]`: в `[tool.ruff]` ruff считает его устаревшим и предупреждает.
  `known-third-party`: в `backend/` есть папка `alembic/`, и без этой строки ruff считает пакет `alembic` своим кодом
  и ставит `from alembic import ...` после импортов `app`.

- [x] **Шаг 3: `backend/.env.example`** — три переменные из спеки 3.3 со значениями по умолчанию и тот же
  комментарий о смене пароля, что в задаче 1.

- [x] **Шаг 4: написать падающий тест** `backend/tests/test_config.py`:

```python
from pathlib import Path

import pytest

from app.core.config import ENV_FILE, Settings

DEV_URL = "postgresql+psycopg://user:secret@localhost:5432/wms_crm"
TEST_URL = "postgresql+psycopg://user:secret@localhost:5432/wms_crm_test"


def test_env_file_is_in_backend_dir() -> None:
    assert ENV_FILE == Path(__file__).resolve().parents[1] / ".env"


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
```

Отклонение (2026-10-26, одобрено владельцем): в `test_env_file_is_in_backend_dir` части сравнения переставлены —
`assert Path(__file__).resolve().parents[1] / ".env" == ENV_FILE`. Причина: в шаге 7 `ruff check` падал на правиле
SIM300 («условие Йоды»): ruff считает имя в верхнем регистре (`ENV_FILE`) константой, а константа слева от `==`
нарушает правило из набора `SIM` (шаг 2). Смысл теста не изменился.

- [x] **Шаг 5: запустить — падает.**

Run (`backend/`): `uv run pytest tests/test_config.py -v`
Expected: FAIL — `ModuleNotFoundError` (`app` или `app.core.config`).

- [x] **Шаг 6: реализовать `app/core/config.py`** — спека 4.2: `ENV_FILE = Path(__file__).resolve().parents[2] / ".env"`,
  `model_config = SettingsConfigDict(env_file=ENV_FILE, extra="ignore")`, значения по умолчанию — из таблицы 3.3.

- [x] **Шаг 7: зелёные тесты и линтеры.**

Run (`backend/`): `uv run pytest -v && uv run ruff check . && uv run ruff format --check . && uv run mypy app`
Expected: 4 passed; ruff и mypy — без ошибок.

### Задача 3: Слой БД и Alembic

**Файлы:**
- Создать: `backend/app/core/db.py`, `backend/app/models/__init__.py`, `backend/app/models/base.py`
- Создать (через `alembic init`, затем править): `backend/alembic.ini`, `backend/alembic/env.py`,
  `backend/alembic/script.py.mako`; плюс `backend/alembic/versions/.gitkeep`
- Удалить: `backend/alembic/README` (его создаёт `alembic init`)

**Интерфейсы:**
- Потребляет: `get_settings().effective_database_url` (задача 2).
- Даёт: `app.core.db.engine: Engine`, `app.core.db.SessionLocal: sessionmaker[Session]`,
  `app.core.db.get_db() -> Iterator[Session]`; `app.models.Base`; `env.py` берёт адрес из
  `config.attributes.get("database_url")` (его передаёт `conftest.py`, задача 4).

Шаги 1–2 — исключение из TDD (см. «Глобальные ограничения»): своих тестов у `base.py` и `db.py` нет, их проверяют
шаг 6 этой задачи и тесты задачи 4.

- [x] **Шаг 1: модели.** `app/models/base.py` — `class Base(DeclarativeBase)` с
  `metadata = MetaData(naming_convention=NAMING_CONVENTION)`:

```python
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}
```

  `app/models/__init__.py` реэкспортирует `Base` (`__all__ = ["Base"]`).

- [x] **Шаг 2: `app/core/db.py`** — спека 4.3: `engine` с `pool_pre_ping=True` и `connect_args={"connect_timeout": 3}`,
  `SessionLocal = sessionmaker(bind=engine)`, `get_db()` — генератор: `with SessionLocal() as session: yield session`.

- [x] **Шаг 3: `uv run alembic init alembic`** (в `backend/`), удалить `alembic/README`, создать пустой
  `alembic/versions/.gitkeep`: git не хранит пустые папки, а без `versions/` `alembic revision` падает.

- [x] **Шаг 4: `alembic.ini`.** Удалить строку `sqlalchemy.url = ...`. Раскомментировать первый вариант шаблона имени:
  `file_template = %%(year)d_%%(month).2d_%%(day).2d_%%(hour).2d%%(minute).2d-%%(rev)s_%%(slug)s`.
  В секции `[post_write_hooks]`:

```ini
hooks = ruff_fix, ruff_format
ruff_fix.type = module
ruff_fix.module = ruff
ruff_fix.options = check --fix REVISION_SCRIPT_FILENAME
ruff_format.type = module
ruff_format.module = ruff
ruff_format.options = format REVISION_SCRIPT_FILENAME
```

- [x] **Шаг 5: `alembic/env.py`** — спека 4.6: `url = config.attributes.get("database_url") or
  get_settings().effective_database_url`; `target_metadata = Base.metadata` (из `app.models`); онлайн —
  `create_engine(url, poolclass=pool.NullPool)`; офлайн — `context.configure(url=url, ...)`; блок `fileConfig(...)`
  из шаблона оставить. Затем `uv run ruff check --fix . && uv run ruff format .`.

- [x] **Шаг 6: проверка Alembic** (БД из задачи 1 запущена).

Run (`backend/`): `uv run alembic upgrade head`
Expected: код 0.

Run: `USE_TEST_DATABASE=true uv run alembic upgrade head && USE_TEST_DATABASE=true uv run alembic check`
Expected: `No new upgrade operations detected.`

Run: `uv run python -c "from app.core.db import engine; print(engine.url.database)"`, затем та же команда
с `USE_TEST_DATABASE=true` в начале.
Expected: `wms_crm`, затем `wms_crm_test` — `engine` берёт адрес из `effective_database_url`.

Run: `TEST_DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm_env_check uv run alembic current`,
затем та же команда с `USE_TEST_DATABASE=true` в начале.
Expected: первая — код 0 (Alembic работает с `wms_crm`); вторая — ошибка `database "wms_crm_env_check" does not exist`:
при `USE_TEST_DATABASE=true` `env.py` берёт тестовый адрес. Базы `wms_crm_env_check` нет, поэтому опыт ничего не меняет.

Run: `uv run alembic revision --autogenerate -m "check template"`
Expected: `Running post write hook 'ruff_fix'` и `'ruff_format'`; файл
`alembic/versions/<ГГГГ>_<ММ>_<ДД>_<ЧЧММ>-<rev>_check_template.py`.

Run: `uv run ruff check . && uv run ruff format --check .`, затем удалить созданный файл миграции.
Expected: ruff зелёный; в `alembic/versions/` остался только `.gitkeep` (и `__pycache__/`, он в `.gitignore`).

- [x] **Шаг 7: проверки.**

Run (`backend/`): `uv run ruff check . && uv run ruff format --check . && uv run mypy app && uv run pytest`
Expected: всё зелёное, 4 passed.

### Задача 4: Эндпоинт `GET /api/health`

**Файлы:**
- Создать: `backend/tests/conftest.py`
- Тест: `backend/tests/test_health.py`
- Создать: `backend/app/schemas/{__init__,health}.py`, `backend/app/services/{__init__,health}.py`,
  `backend/app/api/{__init__,router}.py`, `backend/app/api/routes/{__init__,health}.py`, `backend/app/main.py`

**Интерфейсы:**
- Потребляет: `get_settings()`, `get_db`, `Base`, `alembic.ini` (задачи 2–3).
- Даёт: `app.main.app: FastAPI`; фикстуры `test_engine` (уровень сессии), `db_session`, `client`;
  `HealthResponse(status: Literal["ok", "error"], db: Literal["ok", "error"])`;
  `is_database_available(session: Session) -> bool`; `GET /api/health` → 200 `{"status": "ok", "db": "ok"}`
  или 503 `{"status": "error", "db": "error"}`.

- [x] **Шаг 1: `tests/conftest.py`** — спека 6.1:
  - `test_engine()` — `scope="session"`, без `autouse`: тестам без БД (`test_config.py`, тест 503) она не нужна.
    Берёт `get_settings().test_database_url`; если `make_url(url).database` не оканчивается на `_test` —
    `pytest.exit("TEST_DATABASE_URL must point to a database whose name ends with '_test', got '<имя>'", returncode=1)`
    до любого подключения. Затем в `engine.begin()` — `DROP SCHEMA public CASCADE` и `CREATE SCHEMA public`;
    `command.upgrade(cfg, "head")`, где `cfg = Config(str(BACKEND_DIR / "alembic.ini"))` и
    `cfg.attributes["database_url"] = url`; `yield engine`; `engine.dispose()`.
  - `db_session(test_engine)` — `connection = test_engine.connect()`, `transaction = connection.begin()`,
    `Session(bind=connection, join_transaction_mode="create_savepoint")`; после теста — `session.close()`,
    `transaction.rollback()`, `connection.close()`.
  - `client(db_session)` — `app.dependency_overrides[get_db] = lambda: db_session`;
    `with TestClient(app) as test_client: yield test_client`; затем `app.dependency_overrides.clear()`.

- [x] **Шаг 2: написать падающие тесты** `tests/test_health.py`:

```python
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
```

- [x] **Шаг 3: запустить — падает.**

Run (`backend/`): `uv run pytest tests/test_health.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.main'`.

- [x] **Шаг 4: реализовать** — спека 4.4:
  - `app/schemas/health.py` — `HealthResponse(BaseModel)`.
  - `app/services/health.py` — `is_database_available`: `session.execute(text("SELECT 1"))`, `SQLAlchemyError` → `False`.
  - `app/api/routes/health.py` — `router = APIRouter()`;
    `@router.get("/health", responses={503: {"model": HealthResponse, "description": "Database is unavailable"}})`;
    обычный `def health(response: Response, session: Annotated[Session, Depends(get_db)]) -> HealthResponse`;
    при `False` — `response.status_code = 503`.
  - `app/api/router.py` — `api_router = APIRouter()` и `api_router.include_router(health.router)`.
  - `app/main.py` — `app = FastAPI(title="WMS CRM API")`, `app.include_router(api_router, prefix="/api")`.

- [x] **Шаг 5: тесты зелёные.**

Run (`backend/`): `uv run pytest -v`
Expected: 6 passed, предупреждений `StarletteDeprecationWarning` нет.

Run (корень): `docker compose exec db psql -U postgres -d wms_crm_test -c '\dt'`
Expected: есть таблица `alembic_version`. Фикстура удалила схему и заново применила миграции к `wms_crm_test` —
значит, `env.py` взял адрес из `config.attributes["database_url"]`, а не из настроек (в pytest они указывают на `wms_crm`).

- [x] **Шаг 6: защита тестовой БД (Review Focus 3).**

Run (`backend/`): `TEST_DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm_guard_check uv run pytest`
Expected: прогон останавливается с сообщением про `_test`, код 1. Базы `wms_crm_guard_check` нет: если защита сломана,
будет ошибка подключения, а не сообщение про `_test`, — и ни одна БД не пострадает.

Отклонение (2026-10-26, одобрено владельцем по итогам ревью этапа 1, замечание M1): защита в `conftest.py` —
в два уровня. Проверка имени в пути адреса до подключения осталась; добавлена вторая — `SELECT current_database()`
в той же транзакции перед `DROP SCHEMA` (общая функция `exit_unless_test_database`). Причина: адрес
`…/wms_crm_test?dbname=другая_база` проходил первую проверку, а psycopg подключался к базе из параметра — и `DROP SCHEMA`
выполнялся там. Проверено на временной пустой базе `wms_crm_guard_probe` (создана и удалена с разрешения владельца):
до исправления — 7 passed, схема `public` пробной базы пересоздана (OID 2200 → 16431); после — остановка с
`got 'wms_crm_guard_probe'`, код 1, OID не изменился. Спека 6.1 обновлена. После исправления повторены шаги 5, 6 и 8:
7 passed (с тестом задачи 5), `alembic_version` в `wms_crm_test` есть; защита — сообщение про `_test`, код 1
(до остановки проходят 5 тестов без БД); ruff и mypy без ошибок.

- [x] **Шаг 7: живой сервер.**

Run (`backend/`): `uv run uvicorn app.main:app --reload --port 8000` в фоне, затем
`curl -i http://localhost:8000/api/health`, затем остановить сервер.
Expected: `200 OK`, тело `{"status":"ok","db":"ok"}`.

- [x] **Шаг 8: линтеры и типы.**

Run (`backend/`): `uv run ruff check . && uv run ruff format --check . && uv run mypy app`
Expected: без ошибок.

### Задача 5: Выгрузка OpenAPI

**Файлы:**
- Тест: `backend/tests/test_export_openapi.py`
- Создать: `backend/app/export_openapi.py`

**Интерфейсы:**
- Потребляет: `app.main.app`.
- Даёт: команду `python -m app.export_openapi <путь>` (её вызывают `npm run gen:api`, `check.sh` и CI);
  функцию `export_openapi(path: Path) -> None`.

- [x] **Шаг 1: написать падающий тест** — он вызывает ту же команду, что `gen:api` и `check.sh`:

```python
import json
import subprocess
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]


def test_export_openapi_writes_schema(tmp_path: Path) -> None:
    target = tmp_path / "openapi.json"

    subprocess.run(
        [sys.executable, "-m", "app.export_openapi", str(target)], cwd=BACKEND_DIR, check=True
    )

    text = target.read_text(encoding="utf-8")
    assert text.endswith("}\n")
    responses = json.loads(text)["paths"]["/api/health"]["get"]["responses"]
    assert {"200", "503"} <= responses.keys()
```

- [x] **Шаг 2: запустить — падает.**

Run (`backend/`): `uv run pytest tests/test_export_openapi.py -v`
Expected: FAIL — `CalledProcessError` (`No module named app.export_openapi`).

- [x] **Шаг 3: реализовать `app/export_openapi.py`** — спека 4.5: `export_openapi(path)` пишет в UTF-8
  `json.dumps(app.openapi(), indent=2, ensure_ascii=False) + "\n"`; аргумент — `argparse` с одним позиционным
  `path`, разбор под `if __name__ == "__main__":`.

- [x] **Шаг 4: всё зелёное.**

Run (`backend/`): `uv run pytest -v && uv run ruff check . && uv run ruff format --check . && uv run mypy app`
Expected: 7 passed; ruff и mypy без ошибок.

### Завершение этапа 1

- [x] **Шаг 1:** `git add -A` — чтобы после проверок `git status` показывал только то, что изменили сами проверки.
- [x] **Шаг 2: список проверок для владельца** — точные команды из раздела «Команды» CLAUDE.md и таблицы спеки 1.1
  (команда БД — уже в новом виде, в CLAUDE.md она обновится на этапе 4):

```bash
# корень
docker compose up -d --wait && docker compose ps                  # код 0, db — healthy
docker compose exec db psql -U postgres -lqt                      # есть wms_crm и wms_crm_test
git check-ignore --no-index .env.example backend/.env.example     # пустой вывод

# backend/
uv run uvicorn app.main:app --reload --port 8000
#   в другом терминале: curl -i http://localhost:8000/api/health  → 200, {"status":"ok","db":"ok"}; затем Ctrl+C
uv run pytest                                                     # 7 passed
uv run ruff check . && uv run ruff format --check . && uv run mypy app   # код 0
uv run alembic upgrade head                                       # код 0
uv run alembic revision --autogenerate -m "check template"        # файл в alembic/versions/, имя начинается с даты
uv run ruff check . && uv run ruff format --check .               # зелёный; затем удалить созданный файл миграции

# backend/ — защита тестовой БД от обхода через ?dbname= (временная пустая база: если защита сломана,
# пострадает только её схема)
docker compose exec db psql -U postgres -c 'CREATE DATABASE wms_crm_guard_probe'
TEST_DATABASE_URL='postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm_test?dbname=wms_crm_guard_probe' uv run pytest; echo $?
#   → «... ends with '_test', got 'wms_crm_guard_probe'», последняя строка — 1
docker compose exec db psql -U postgres -c 'DROP DATABASE wms_crm_guard_probe'

# корень
git status --short    # только строки «A » (и, возможно, файлы плана и спеки)
```

- [x] **Шаг 3: после подтверждения — коммит.** `git add -A` (захватит отметки чекбоксов в плане), затем
  `git commit -m "feat: add backend skeleton with health endpoint and local database"`. Остановка до команды на этап 2.

---

## Этап 2. Фронтенд

### Задача 6: Проект Next.js и инструменты

**Файлы:**
- Создать (через `create-next-app`): `frontend/` — `package.json`, `package-lock.json`, `tsconfig.json`,
  `next.config.ts`, `eslint.config.mjs`, `.gitignore`, `AGENTS.md`, `src/app/*`, `public/*`
- Удалить: `frontend/README.md`
- Создать: `frontend/.nvmrc`, `frontend/CLAUDE.md`, `frontend/.prettierrc`, `frontend/.prettierignore`,
  `frontend/.env.example`
- Изменить: `frontend/package.json`, `tsconfig.json`, `eslint.config.mjs`, `.gitignore`, `next.config.ts`

**Интерфейсы:**
- Даёт: скрипты `lint`, `format`, `format:check`, `typecheck`; `next.config.ts` с `distDir` и rewrites
  (обёртку next-intl добавит задача 10).

- [x] **Шаг 1: создать проект** (из корня; версия — та, что проверена):

```bash
npx create-next-app@16.4.2 frontend --ts --tailwind --eslint --app --src-dir --import-alias "@/*" \
  --use-npm --no-react-compiler --no-cache-components --agents-md --no-agent-feedback --disable-git --yes
```

Expected: «Success! Created frontend», вопросов нет; есть `frontend/AGENTS.md`; нет `CLAUDE.md` и
`postcss.config.mjs`; в `next.config.ts` — блок `turbopack.rules` с `@tailwindcss/turbopack`.

- [x] **Шаг 2: служебные файлы.** Удалить `frontend/README.md`. `.nvmrc` — `24`. `CLAUDE.md` — одна строка
  `@AGENTS.md`. `.env.example` — `BACKEND_URL=http://localhost:8000`. `AGENTS.md` не трогать.

- [x] **Шаг 3: зависимости.**

Run (`frontend/`): `npm install -D @types/node@^24 prettier eslint-config-prettier` (зачем Prettier
и eslint-config-prettier — таблица спеки 5.1)

`@types/node` поднимается с `^20` (так ставит шаблон) до `^24`: у нас Node 24, а Vitest 5 (задача 8) требует
`@types/node` ≥ 22 — с `^20` его установка падает с `ERESOLVE`.

- [x] **Шаг 4: конфигурация** — спека 5.2 и 5.5:
  - `package.json`, `scripts`: `lint` = `eslint .`, `format` = `prettier --write .`, `format:check` = `prettier --check .`,
    `typecheck` = `next typegen && tsc --noEmit`.
  - `.prettierrc` — `{}`: настройки Prettier по умолчанию, тот же стиль, что у шаблона.
  - `.prettierignore` — `.next/`, `.next-e2e/`, `out/`, `build/`, `next-env.d.ts`, `playwright-report/`, `test-results/`,
    `blob-report/`, `openapi.json`, `src/lib/api/schema.d.ts`, `AGENTS.md` (его ведёт Next.js; форматирование
    не должно его менять).
  - `eslint.config.mjs` — последним элементом конфиг из `eslint-config-prettier/flat`; `globalIgnores` — список из спеки 5.2.
  - `tsconfig.json`, `include` — добавить `.next-e2e/types/**/*.ts` и `.next-e2e/dev/types/**/*.ts`.
  - `.gitignore` — `!.env.example` сразу после `.env*`; `/.next-e2e/`.
  - `next.config.ts` — блок `turbopack` оставить; добавить `distDir: process.env.NEXT_DIST_DIR ?? ".next"` и `rewrites()`,
    возвращающий `` [{ source: "/api/:path*", destination: `${backendUrl}/api/:path*` }] ``, где
    `backendUrl = process.env.BACKEND_URL ?? "http://localhost:8000"`.

- [x] **Шаг 5: проверка.**

Run (`frontend/`): `npm run format && npm run lint && npm run format:check && npm run typecheck`
Expected: код 0.

Run (корень): `git check-ignore --no-index frontend/.env.example`
Expected: пустой вывод.

### Задача 7: shadcn/ui (Base UI) — `card` и `badge`

**Файлы:**
- Создать (через `shadcn`): `frontend/components.json`, `frontend/src/lib/utils.ts`,
  `frontend/src/components/ui/card.tsx`, `frontend/src/components/ui/badge.tsx`
- Изменить (через `shadcn`): `frontend/src/app/globals.css`, `frontend/package.json`
- Удалить: `frontend/src/components/ui/button.tsx` (его создаёт `init`; по спеке нужны только `card` и `badge`)

**Интерфейсы:**
- Даёт: `Card`, `CardContent` (и остальные части карточки) из `@/components/ui/card`; `Badge` с
  `variant: "default" | "secondary" | "destructive" | "outline" | "ghost" | "link"` из `@/components/ui/badge`.

- [x] **Шаг 1: init.**

Run (`frontend/`): `npx shadcn@4.22.0 init --base base --preset nova --template next --no-monorepo`
Expected: без вопросов, «Project initialization completed»; в `dependencies` — `@base-ui/react`,
`class-variance-authority`, `cn`, `lucide-react`, `shadcn`, `tw-animate-css` (таблица спеки 5.1 и пояснение под ней);
в `components.json` — `"style": "base-nova"`.

Отклонение (2026-10-26, по правилу владельца для патч-версий): CLI запущен версии 4.22.0, но в `dependencies`
`init` записал `shadcn` `^4.22.1` (последняя версия на момент установки). Changelog 4.22.1 просмотрен: единственное
исправление — `shadcn add --all` и интерактивный выбор компонентов показывают только компоненты стиля проекта;
мы добавляем компоненты по именам (`add card badge`), план не затронут.

- [x] **Шаг 2: компоненты.**

Run: `npx shadcn@4.22.0 add card badge`, затем удалить `src/components/ui/button.tsx`.

- [x] **Шаг 3: форматирование и проверки.**

Run: `npm run format && npm run lint && npm run format:check && npm run typecheck`
Expected: код 0.

### Задача 8: Vitest — статус бэкенда и переводы

**Файлы:**
- Создать: `frontend/vitest.config.mts`, `frontend/messages/ru.json`, `frontend/messages/en.json`,
  `frontend/src/lib/backend-status.ts`
- Тест: `frontend/src/lib/backend-status.test.ts`, `frontend/src/i18n/messages.test.ts`
- Изменить: `frontend/package.json` (скрипт `test`)

**Интерфейсы:**
- Даёт (в `src/lib/backend-status.ts`): `type BackendState = "checking" | "ok" | "unavailable"`;
  `type HealthCheckResult = { status: number } | { networkError: true }`;
  `resolveBackendStatus(result: HealthCheckResult): Exclude<BackendState, "checking">`.
  Ключи `BackendStatus.*` в переводах совпадают со значениями `BackendState`, поэтому компонент пишет `t(status)`.
  Тип назван `BackendState`, а не `BackendStatus`, чтобы не совпасть с именем компонента из задачи 10.

- [x] **Шаг 1: Vitest.**

Run (`frontend/`): `npm install -D vitest` (таблица спеки 5.1). Скрипт `test` = `vitest run`. `vitest.config.mts` —
`defineConfig({ test: { environment: "node", include: ["src/**/*.test.ts"] } })` из `vitest/config`.
Тесты импортируют модули по относительным путям: алиас `@/` Vitest сам не читает.

- [x] **Шаг 2: написать падающие тесты.**

`src/lib/backend-status.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { resolveBackendStatus } from "./backend-status";

describe("resolveBackendStatus", () => {
  it("returns ok for HTTP 200", () => {
    expect(resolveBackendStatus({ status: 200 })).toBe("ok");
  });

  it.each([404, 500, 503])("returns unavailable for HTTP %i", (status) => {
    expect(resolveBackendStatus({ status })).toBe("unavailable");
  });

  it("returns unavailable for a network error", () => {
    expect(resolveBackendStatus({ networkError: true })).toBe("unavailable");
  });
});
```

`src/i18n/messages.test.ts` (вспомогательная `flattenKeys` — внутри теста):

```ts
import { describe, expect, it } from "vitest";

import en from "../../messages/en.json";
import ru from "../../messages/ru.json";

function flattenKeys(messages: object, prefix = ""): string[] {
  return Object.entries(messages).flatMap(([key, value]) =>
    typeof value === "object" && value !== null
      ? flattenKeys(value, `${prefix}${key}.`)
      : [`${prefix}${key}`],
  );
}

describe("messages", () => {
  it("ru and en have the same keys", () => {
    expect(flattenKeys(en).sort()).toEqual(flattenKeys(ru).sort());
  });

  it("flattens nested keys", () => {
    expect(flattenKeys(ru)).toContain("BackendStatus.ok");
  });
});
```

- [x] **Шаг 3: запустить — падают.**

Run: `npm run test`
Expected: FAIL — не найдены `./backend-status` и `../../messages/en.json`.

- [x] **Шаг 4: реализовать.** `messages/ru.json` и `messages/en.json` — ключи и тексты из таблицы спеки 5.3,
  вложенными объектами (`{"Metadata": {"title": ...}, "HomePage": {...}, "BackendStatus": {...}}`).
  `src/lib/backend-status.ts` — типы и функция из «Интерфейсов»: 200 → `"ok"`, всё остальное → `"unavailable"`.

- [x] **Шаг 5: всё зелёное.**

Run: `npm run test && npm run lint && npm run format:check && npm run typecheck`
Expected: 7 passed; остальное — код 0.

### Задача 9: API-клиент и `gen:api`

**Файлы:**
- Создать: `frontend/openapi.json`, `frontend/src/lib/api/schema.d.ts` (генерируются), `frontend/src/lib/api/client.ts`
- Изменить: `frontend/package.json` (скрипт `gen:api`)

**Интерфейсы:**
- Потребляет: `python -m app.export_openapi <путь>` (задача 5).
- Даёт: `export const api = createClient<paths>()` в `src/lib/api/client.ts` (`baseUrl` не задан; `paths` — из `./schema`).

- [x] **Шаг 1: зависимости и скрипт.**

Run (`frontend/`): `npm install openapi-fetch && npm install -D openapi-typescript` (таблица спеки 5.1).
Скрипт `gen:api` — дословно из спеки 5.4.

- [x] **Шаг 2: генерация повторяется байт в байт.**

Run (бэкенд не запущен): `npm run gen:api`, скопировать оба файла в scratchpad, снова `npm run gen:api`, сравнить
копии с файлами через `cmp`.
Expected: файлы созданы; `cmp` молчит.

- [x] **Шаг 3: `src/lib/api/client.ts`** — см. «Интерфейсы». Исключение из TDD (см. «Глобальные ограничения»):
  своего теста нет, файл проверяют `typecheck` в шаге 4 и e2e задачи 10.

- [x] **Шаг 4: проверки.**

Run: `npm run lint && npm run format:check && npm run typecheck`
Expected: код 0 (сгенерированные файлы исключены из ESLint и Prettier).

### Задача 10: Главная страница и e2e

**Файлы:**
- Создать: `frontend/playwright.config.ts`, `frontend/e2e/global-teardown.ts`, `frontend/src/i18n/config.ts`,
  `frontend/src/i18n/request.ts`, `frontend/src/global.ts`, `frontend/src/components/backend-status.tsx`
- Тест: `frontend/e2e/home.spec.ts`
- Изменить: `frontend/next.config.ts`, `frontend/src/app/layout.tsx`, `frontend/src/app/page.tsx`,
  `frontend/package.json` (скрипт `test:e2e`)
- Удалить: картинки шаблона `frontend/public/{file,globe,next,vercel,window}.svg`

**Интерфейсы:**
- Потребляет: `api` (задача 9); `resolveBackendStatus`, `BackendState` (задача 8); `Card`, `CardContent`, `Badge`
  (задача 7); `GET /api/health` (задача 4).
- Даёт: `locales`, `defaultLocale`, `type Locale` из `src/i18n/config.ts`; компонент `BackendStatus`
  из `src/components/backend-status.tsx`.

- [x] **Шаг 1: Playwright.**

Run (`frontend/`): `npm install -D @playwright/test && npx playwright install chromium` (таблица спеки 5.1). Если Chromium не стартует
из-за системных библиотек — попросить владельца выполнить `sudo npx playwright install-deps chromium`.
Скрипт `test:e2e` = `playwright test`.

`playwright.config.ts` — спека 6.3: `testDir: "./e2e"`; один проект `chromium` (`devices["Desktop Chrome"]`);
`use.baseURL: "http://localhost:3001"`; `retries: process.env.CI ? 1 : 0`; `forbidOnly: !!process.env.CI`;
`reporter: [["list"], ["html", { open: "never" }]]`; `globalTeardown: "./e2e/global-teardown.ts"`; `webServer` —
массив из двух серверов: команды, `env`, `url` и `timeout` (60 000 и 180 000 мс) — из таблицы спеки 6.3,
у обоих `reuseExistingServer: false`.

`e2e/global-teardown.ts` — `export default async function globalTeardown(): Promise<void>`: удаляет
`path.resolve(__dirname, "../.next-e2e")` через `rm(..., { recursive: true, force: true })`.

- [x] **Шаг 2: написать падающий e2e-тест** `e2e/home.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

const TITLE = "Система управления складом";

test("shows the title and a running backend", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle(TITLE);
  await expect(page.locator("html")).toHaveAttribute("lang", "ru");
  await expect(
    page.getByRole("heading", { level: 1, name: TITLE }),
  ).toBeVisible();
  await expect(page.getByText("Бэкенд: работает")).toBeVisible();
});

test("shows unavailable backend when health returns 503", async ({ page }) => {
  await page.route("**/api/health", (route) =>
    route.fulfill({ status: 503, json: { status: "error", db: "error" } }),
  );
  await page.goto("/");

  await expect(page.getByText("Бэкенд: недоступен")).toBeVisible();
});

test("shows unavailable backend when the connection fails", async ({
  page,
}) => {
  await page.route("**/api/health", (route) => route.abort());
  await page.goto("/");

  await expect(page.getByText("Бэкенд: недоступен")).toBeVisible();
});
```

Отклонение (2026-10-26, одобрено владельцем): текст теста заменён на вывод Prettier — две строки длиннее 80 символов
(проверка заголовка `h1` и заголовок третьего теста) перенесены. Причина: при предпроверке в задаче 6
(`prettier --check --stdin-filepath e2e/home.spec.ts`) исходный текст не проходил проверку, а в задаче 10 нет шага
`npm run format` — упал бы `format:check` в шаге 7. Селекторы, тексты и проверки не изменились.

- [x] **Шаг 3: запустить — падает.**

Run (`frontend/`, БД запущена): `npm run test:e2e`
Expected: сборка и оба сервера стартуют; 3 теста FAIL — на странице шаблона нет «Система управления складом».

- [x] **Шаг 4: next-intl.**

Run: `npm install next-intl` (таблица спеки 5.1).
  - `src/i18n/config.ts` — спека 5.3: `locales = ["ru", "en"] as const`, `type Locale = (typeof locales)[number]`,
    `defaultLocale: Locale = "ru"`.
  - `src/i18n/request.ts` — `getRequestConfig` всегда возвращает `locale: defaultLocale` и
    `` messages: (await import(`../../messages/${defaultLocale}.json`)).default ``.
  - `src/global.ts` — `declare module "next-intl" { interface AppConfig { Locale: (typeof locales)[number]; Messages: typeof messages } }`;
    `messages` — `import type` из `../messages/ru.json`, `locales` — `import type` из `./i18n/config`.
  - `next.config.ts` — `export default createNextIntlPlugin()(nextConfig)`.

- [x] **Шаг 5: layout, компонент, страница.**
  - `src/app/layout.tsx` — `async RootLayout`: `const locale = await getLocale()`, `<html lang={locale} ...>`, дети —
    внутри `<NextIntlClientProvider>`. `generateMetadata(): Promise<Metadata>` возвращает `{ title: t("title") }`
    через `getTranslations("Metadata")`; описание шаблона убрать. Шрифт `Geist` — с `variable: "--font-sans"`
    (этого имени ждёт `globals.css` после shadcn), `Geist_Mono` — как в шаблоне.
  - `src/components/backend-status.tsx` — `"use client"`; состояние типа `BackendState`, начальное `"checking"`; в `useEffect` —
    асинхронная проверка: `try { const { response } = await api.GET("/api/health"); ... resolveBackendStatus({ status: response.status }) }`,
    `catch` → `resolveBackendStatus({ networkError: true })`. Состояние меняется только после `await` и только если
    компонент ещё на странице (флаг отмены в функции очистки эффекта). Разметка — `<Badge aria-live="polite" variant={...}>{t(status)}</Badge>`;
    варианты: `checking` → `"outline"`, `ok` → `"default"`, `unavailable` → `"destructive"`.
  - `src/app/page.tsx` — серверный компонент: `useTranslations("HomePage")`; `<main>` с `<h1>{t("title")}</h1>` и
    `<Card><CardContent><BackendStatus /></CardContent></Card>`.
  - Удалить картинки шаблона из `public/`.

- [x] **Шаг 6: e2e зелёные, рабочие файлы не тронуты.**

Run (`frontend/`): `git add -A .` (чтобы после прогона были видны изменения), затем `npm run test:e2e`,
затем `ls -d .next-e2e; git status --short .`
Expected: 3 passed; `.next-e2e` — «No such file or directory»; в `git status` только строки `A `
(в том числе `tsconfig.json` не изменён).

- [x] **Шаг 7: проверки после e2e (Review Focus 4).**

Run: `npm run typecheck && npm run lint && npm run format:check && npm run test`
Expected: код 0 — хотя `next build` переписал `next-env.d.ts` на `.next-e2e`, `next typegen` вернул ссылки на `.next`.

- [x] **Шаг 8: опечатка в ключе ловится (спека 5.3).** Временно заменить в `page.tsx` `t("title")` на `t("titel")`.

Run: `npm run typecheck`
Expected: FAIL — `TS2345: Argument of type '"titel"' is not assignable to parameter of type '"title"'`.
Вернуть `t("title")`; `npm run typecheck` — зелёный.

- [x] **Шаг 9: dev-режим.** Запустить бэкенд на 8000 и `npm run dev` (оба в фоне).

Run: `curl -s http://localhost:3000 | grep -c "Система управления складом"` и `curl -s http://localhost:3000/api/health`
Expected: число > 0; `{"status":"ok","db":"ok"}` (запрос прошёл через rewrite). Остановить оба сервера;
`git status --short AGENTS.md` — без изменений.

### Завершение этапа 2

- [x] **Шаг 1:** `git add -A`.
- [x] **Шаг 2: список проверок для владельца** — точные команды из раздела «Команды» CLAUDE.md и таблицы спеки 1.1
  (БД запущена):

```bash
# frontend/
npm run lint && npm run format:check && npm run typecheck   # код 0
npm run test                                                # 7 passed
npm run test:e2e                                            # 3 passed
git status --short    # только «A » (и, возможно, файл плана); папки .next-e2e нет
npm run gen:api       # бэкенд НЕ запущен; код 0
git status --short    # то же: типы свежие
git check-ignore --no-index .env.example                    # пустой вывод

# backend/ — в отдельном терминале
uv run uvicorn app.main:app --reload --port 8000

# frontend/
npm run dev           # открыть http://localhost:3000, затем Ctrl+C в обоих терминалах
```

  На странице: заголовок «Система управления складом» и метка «Бэкенд: работает».
  **Стили Tailwind применились**, если: шрифт без засечек; статус лежит в карточке со скруглёнными углами и тонкой
  серой рамкой; метка «Бэкенд: работает» — тёмная «таблетка» с белым текстом. Если на странице чёрный текст
  с засечками без рамок и плашек — Tailwind не подключился (например, обёртка next-intl затёрла `turbopack.rules`
  в `next.config.ts`).
- [x] **Шаг 3: после подтверждения — коммит.** `git add -A` (захватит отметки чекбоксов в плане), затем
  `git commit -m "feat: add frontend skeleton with backend status page"`. Остановка до команды на этап 3.

---

## Этап 3. Единый скрипт проверок

### Задача 11: `scripts/check.sh`

**Файлы:**
- Создать: `scripts/check.sh` (с битом исполнения)
- Изменить: `.gitignore` (корень) — добавить `.tmp/`

**Интерфейсы:**
- Потребляет: команды этапов 1–2; `python -m app.export_openapi`; `frontend/node_modules/.bin/openapi-typescript`;
  `get_settings().test_database_url`.
- Даёт: `./scripts/check.sh` из любой папки; код 0 — все проверки OK, иначе 1.

- [ ] **Шаг 1: написать скрипт** — спека 7. Решения, которых в спеке нет:
  - `#!/usr/bin/env bash` и `set -uo pipefail` — без `-e`: падение одной проверки не останавливает остальные.
  - `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.
  - Временная папка: `mkdir -p "$ROOT/.tmp"`, `TMP_DIR="$(mktemp -d "$ROOT/.tmp/check.XXXXXX")"`,
    `trap 'rm -rf "$TMP_DIR"' EXIT`, плюс `trap 'exit 130' INT` и `trap 'exit 143' TERM` — так ловушка `EXIT`
    гарантированно срабатывает и при Ctrl+C.
  - Предусловие БД: в `backend/` — `uv run python -c "..."`, который выполняет `SELECT 1` через
    `create_engine(get_settings().test_database_url, connect_args={"connect_timeout": 3})`; вывод скрыт. При ошибке —
    «БД недоступна: запусти `docker compose up -d --wait` в корне проекта» и `exit 1`. Нет `frontend/node_modules` —
    «выполни `npm ci` в папке frontend/» и `exit 1`.
  - Функция `run_check "<имя>" "<папка>" <команда...>`: печатает `==> <имя>`, выполняет команду в подоболочке
    `(cd "<папка>" && "$@")`, запоминает OK или FAIL.
  - Проверки 1–10 — в порядке спеки 7.4. Проверка 5 —
    `env USE_TEST_DATABASE=true bash -c 'uv run alembic upgrade head && uv run alembic check'`.
    Проверка 10 — функция `check_api_types`: `uv run --directory "$ROOT/backend" python -m app.export_openapi "$TMP_DIR/openapi.json"`,
    затем из `frontend/` — `./node_modules/.bin/openapi-typescript "$TMP_DIR/openapi.json" -o "$TMP_DIR/schema.d.ts"`,
    затем `cmp -s` с `frontend/openapi.json` и `frontend/src/lib/api/schema.d.ts`. При расхождении или отсутствии файла —
    подсказка «выполни `npm run gen:api` в папке frontend/». Над функцией — комментарий, что команды должны совпадать
    с `gen:api` в `frontend/package.json`.
  - Сводка: каждая проверка — `OK` или `FAIL`; `exit 1`, если есть хоть один FAIL.
  - Сообщения для человека — по-русски (как в спеке), комментарии в коде — по-английски.

- [ ] **Шаг 2: бит исполнения и `.gitignore`.** `chmod +x scripts/check.sh`; в корневой `.gitignore` — `.tmp/`.

- [ ] **Шаг 3: опыт — свежие файлы, запуск из другой папки.**

Run: `(cd frontend && ../scripts/check.sh); ls -A .tmp`
Expected: 10 × OK, код 0; `.tmp/` пуста.

- [ ] **Шаг 4: опыт — изменённый эндпоинт без `gen:api`.** Временно добавить `summary="Health check"`
  в декоратор в `backend/app/api/routes/health.py`.

Run: `./scripts/check.sh; ls -A .tmp`
Expected: проверка 10 — FAIL с подсказкой про `npm run gen:api`, код 1; `.tmp/` пуста. Вернуть код — снова всё OK.

- [ ] **Шаг 5: опыт — нет сгенерированного файла (Review Focus 5).** Временно перенести
  `frontend/src/lib/api/schema.d.ts` в scratchpad.

Run: `./scripts/check.sh; ls -A .tmp`
Expected: проверка 10 — FAIL с той же подсказкой (typecheck тоже FAIL — ожидаемо); остальные проверки выполнены,
сводка напечатана, код 1; `.tmp/` пуста. Вернуть файл — всё OK.

- [ ] **Шаг 6: опыт — прерывание.**

Run: `timeout -s INT 15 ./scripts/check.sh; ls -A .tmp`
Expected: скрипт завершён по сигналу (код 124 от `timeout`), `.tmp/` пуста.

### Завершение этапа 3

- [ ] **Шаг 1:** `git add -A`; `git ls-files -s scripts/check.sh` — режим `100755`.
- [ ] **Шаг 2: список проверок для владельца** (БД запущена; при желании — ещё опыты из шагов 4–5):

```bash
# корень
./scripts/check.sh                   # 10 × OK, код 0
# backend/
../scripts/check.sh                  # то же из другой папки
../scripts/check.sh                  # ещё раз, нажать Ctrl+C посреди прогона
# корень
ls -A .tmp                           # пустой вывод
git status --short                   # только «A » (и, возможно, файл плана)
```

- [ ] **Шаг 3: после подтверждения — коммит.** `git add -A` (захватит отметки чекбоксов в плане), затем
  `git commit -m "chore: add check script for linters, tests and API types"`. Остановка до команды на этап 4.

---

## Этап 4. CI и документация

### Задача 12: GitHub Actions

**Файлы:**
- Создать: `.github/workflows/ci.yml`

**Интерфейсы:**
- Потребляет: команды бэкенда, `npm run *`, `npm run test:e2e` с его `webServer`.

- [ ] **Шаг 1: workflow** — спека 8. Зафиксировано:
  - `on`: `pull_request` и `push` в `main`; `permissions: contents: read`;
    `concurrency: { group: "ci-${{ github.ref }}", cancel-in-progress: true }`.
  - Actions: `actions/checkout@v7`, `actions/setup-node@v7`, `astral-sh/setup-uv@v10.3.0`, `actions/upload-artifact@v7`.
  - setup-uv — `with: working-directory: backend` (кэш по `backend/uv.lock`; Python uv берёт из `backend/.python-version`).
  - setup-node — `node-version-file: frontend/.nvmrc`, `cache: npm`, `cache-dependency-path: frontend/package-lock.json`.
  - Сервис Postgres (задания `backend` и `e2e`): `image: postgres:18`; `env`: `POSTGRES_USER: postgres`,
    `POSTGRES_PASSWORD: postgres`, `POSTGRES_DB: wms_crm_test`; `ports: ["5432:5432"]`;
    `options: --health-cmd "pg_isready -h localhost -U postgres" --health-interval 5s --health-timeout 5s --health-retries 10`.
  - `backend`: `defaults.run.working-directory: backend`; шаги — из таблицы спеки 8; последний —
    `uv run alembic upgrade head && uv run alembic check` с `env: USE_TEST_DATABASE: "true"`.
  - `frontend`: `defaults.run.working-directory: frontend`; шаги — из таблицы спеки 8; `uv sync --locked` —
    с `working-directory: backend`; сравнение типов —
    `git diff --exit-code -- frontend/openapi.json frontend/src/lib/api/schema.d.ts` с
    `working-directory: ${{ github.workspace }}` (корень репозитория).
  - `e2e`: `timeout-minutes: 20`; `defaults.run.working-directory: frontend` — для `npm ci`,
    `npx playwright install --with-deps chromium` и `npm run test:e2e`; setup-uv и `uv sync --locked` —
    с `working-directory: backend`; остальные шаги — из таблицы спеки 8. Отчёт — `if: failure()`,
    `name: playwright-report`, `path: frontend/playwright-report` (путь от корня репозитория: `defaults.run`
    на шаги с `uses:` не действует), `retention-days: 7`.

- [ ] **Шаг 2: синтаксис YAML.**

Run (корень): `uv run --no-project --with pyyaml python -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`
Expected: без ошибок. Настоящая проверка — зелёный CI на PR (завершение этапа 4).

### Задача 13: Документация

**Файлы:**
- Изменить: `README.md`, `CLAUDE.md` (корень), `frontend/CLAUDE.md`
- Создать: `backend/CLAUDE.md`, `docs/ROADMAP.md`

**Интерфейсы:**
- Потребляет: точные имена команд и скриптов из этапов 1–3.

- [ ] **Шаг 1: `README.md`** — спека 9; разделы: «Требования», «Первый запуск» (включая браузер для Playwright),
  «Команды», «E2E-тесты», «Смена пароля БД», «Пересоздание БД», «Структура проекта».
  Плюс правило из раздела «Отложенные замечания ревью этапа 2» (M1): после клонирования и после `npm run test:e2e`
  выполнить `npm run typecheck` (или `npm run dev`), чтобы редактор видел типы Next.js.
- [ ] **Шаг 2: корневой `CLAUDE.md`** — четыре правки из спеки 9: команда БД — `docker compose up -d --wait`;
  в строке про e2e — не запускать одновременно с pytest; «Библиотеки» — Next.js через
  `frontend/node_modules/next/dist/docs/`, остальное через Context7; «SQLAlchemy 2.0» → «SQLAlchemy 2».
- [ ] **Шаг 3: `backend/CLAUDE.md`** — содержание из спеки 9. Плюс два правила из раздела «Отложенные замечания
  ревью этапа 1» (в конце плана):
  - перед первым тестом с `caplog` добавить `disable_existing_loggers=False` в `fileConfig` в `alembic/env.py`;
  - в коде приложения доступ к БД — только через `get_db`; `SessionLocal` напрямую не использовать.
- [ ] **Шаг 4: `frontend/CLAUDE.md`** — под строкой `@AGENTS.md` правила из спеки 9; затем `npm run format` в `frontend/`.
  Плюс правило: после `npx shadcn add` — сразу `npm run format`: shadcn генерирует код не в стиле Prettier проекта,
  и без этого упадёт `format:check` (замечено в задаче 7). И правило M1 (как в шаге 1): после клонирования и после
  `npm run test:e2e` — `npm run typecheck` (или `npm run dev`), чтобы редактор видел типы Next.js.
- [ ] **Шаг 5: `docs/ROADMAP.md`** — таблица «Модуль | Статус»: скелет проекта — готово; пользователи и роли, каталог
  товаров, склады, остатки и движения, переключение языка ru/en — запланировано.
- [ ] **Шаг 6: проверка.** Каждая команда из README и всех CLAUDE.md существует (скрипты `package.json`, `check.sh`).
  Два нумерованных списка подряд в документах разделены строкой текста, иначе Markdown склеит их в один.

Run: `./scripts/check.sh`
Expected: все OK.

### Завершение этапа 4 и ветки

- [ ] **Шаг 1:** `./scripts/check.sh` и `npm run test:e2e` (в `frontend/`) — зелёные; `git add -A`.
- [ ] **Шаг 2: проверка владельцем** — все команды раздела «Команды» CLAUDE.md (уже после правок задачи 13);
  ожидаемое — таблица спеки 1.1, стили Tailwind — как в «Завершении этапа 2»:

```bash
# корень
docker compose up -d --wait && docker compose ps
./scripts/check.sh

# backend/
uv run uvicorn app.main:app --reload --port 8000    # + curl -i http://localhost:8000/api/health, затем Ctrl+C
uv run pytest
uv run ruff check . && uv run ruff format --check . && uv run mypy app
uv run alembic upgrade head
uv run alembic revision --autogenerate -m "check template"   # затем ruff check / format --check и удалить файл

# frontend/
npm run dev           # бэкенд на 8000 запущен; http://localhost:3000, затем Ctrl+C
npm run lint && npm run format:check && npm run typecheck
npm run test
npm run test:e2e
npm run gen:api       # бэкенд не запущен

# корень — после всех команд
git status --short    # только «A » (и, возможно, файл плана)
```

- [ ] **Шаг 3: после подтверждения — два коммита.** `git commit` с путём после `--` берёт в коммит только этот файл;
  всё остальное остаётся в индексе и уходит вторым коммитом (вместе с отметками чекбоксов в плане):

```bash
git add -A
git commit -m "chore: add CI workflow" -- .github/workflows/ci.yml
git commit -m "docs: add README, roadmap and CLAUDE.md rules"
```
- [ ] **Шаг 4: финальное ревью ветки** — superpowers:requesting-code-review, модель ревьюера явно — **opus** (дифф меняет
  `.env.example` и пароли БД). Замечания — через superpowers:receiving-code-review; исправления коммитятся после
  подтверждения.
- [ ] **Шаг 5: завершение ветки** — superpowers:finishing-a-development-branch, вариант «Push and create a Pull Request»
  (push и `gh pr create` — после подтверждения).
- [ ] **Шаг 6: CI** — `gh pr checks`: задания `backend`, `frontend`, `e2e` зелёные. Если нет —
  superpowers:systematic-debugging.

---

## Отложенные замечания ревью этапа 1

Ревью staged-изменений этапа 1 (2026-10-26, модель opus). Исправлено сразу: M1 (защита тестовой БД в два уровня —
см. отклонение в задаче 4, шаге 6) и P2 (фактические версии в спеке 4.1). Не исправляются (решение владельца):
M5 — таймаут в `test_health.py` продублирован намеренно, спека 6.1 требует «тот же `connect_timeout=3`»;
M6 — `DROP SCHEMA` без `IF EXISTS` — так в спеке, ошибка при ручном удалении схемы понятна;
M7 — `dependency_overrides.clear()` — так в плане, вреда нет.

Отложены:

- **M2 — `fileConfig` в `alembic/env.py` отключает существующие логгеры.** Фикстура `test_engine` вызывает
  `command.upgrade` внутри процесса pytest, и `fileConfig(...)` с `disable_existing_loggers=True` (по умолчанию)
  отключает уже созданные логгеры приложения. Почему отложено: сейчас логов в тестах нет, вреда нет. Когда вернуться:
  перед первым тестом с `caplog` — добавить `disable_existing_loggers=False` (правило — в `backend/CLAUDE.md`,
  задача 13, шаг 3).
- **M3 — ответ 503 в `/api/health` ничего не пишет в лог.** Почему отложено: формат и уровни логирования
  приложения ещё не определены. Когда вернуться: при выборе подхода к логированию бэкенда (не позже первого
  бизнес-модуля) — `logger.warning(..., exc_info=True)` в `is_database_available`.
- **M4 — `prepend_sys_path = .` в `alembic.ini` зависит от текущей папки.** Alembic работает только при запуске
  из `backend/` (так написано во всех командах, так же работают `check.sh` и CI). Почему отложено: реальной
  поломки нет. Когда вернуться: если понадобится запускать Alembic из другой папки — `prepend_sys_path = %(here)s`.
- **P1 — во время pytest `engine` и `SessionLocal` приложения смотрят на рабочую `wms_crm`** (спека 6.1: тесты идут
  через `db_session`). Если код приложения возьмёт `SessionLocal` напрямую (например, при запуске приложения или
  в фоновой задаче), pytest молча будет писать в рабочую базу. Почему отложено: дизайн спеки в этом коммите
  не меняем. Когда вернуться: при проектировании первого бизнес-модуля бэкенда (вариант — `USE_TEST_DATABASE=true`
  в начале `conftest.py`; тогда нужна новая проверка того, что `env.py` берёт адрес из `config.attributes`).
  До решения — правило в `backend/CLAUDE.md` (задача 13, шаг 3): доступ к БД только через `get_db`.
- **Пример ответа 503 в `/docs` показывает `{"status":"ok","db":"ok"}`** (замечание владельца). У 503 та же схема
  `HealthResponse`, а Swagger UI строит пример из первого значения каждого `Literal`. Почему отложено: соглашения
  о примерах в OpenAPI ещё нет. Когда вернуться: когда договоримся о примерах в OpenAPI для эндпоинтов.
  Исправление — явный пример `{"status": "error", "db": "error"}` для 503 в `responses` декоратора; после этого —
  `npm run gen:api` (типы API изменятся).

## Отложенные замечания ревью этапа 2

Ревью staged-изменений этапа 2 (2026-10-26, модель opus): Critical и Important нет. Исправлено сразу (решение
владельца): M2 — в `frontend/.env.example` комментарий к `BACKEND_URL` (адрес читается при запуске `next dev`
и `next build` и запоминается в сборке); M4 — из `next.config.ts` убран комментарий шаблона `/* config options here */`.

Отложены:

- **M1 — после `npm run test:e2e` файл `next-env.d.ts` ссылается на удалённую `.next-e2e`.** `next build` переписывает
  этот файл (он в `.gitignore`); `npm run typecheck` и `npm run dev` возвращают ссылки на `.next` (Review Focus 4).
  Но редактор или голый `tsc` на свежем клоне без `.next/` показывают `Cannot find name 'LayoutProps'` в `layout.tsx`.
  Почему отложено: скрипты и CI не затронуты, код менять не нужно. Когда вернуться: задача 13 — правило в README
  (шаг 1) и в `frontend/CLAUDE.md` (шаг 4): после клонирования и после `npm run test:e2e` выполнить
  `npm run typecheck` (или `npm run dev`), чтобы редактор видел типы Next.js.
- **M3 — `BackendStatus` не отменяет запрос `/api/health` при размонтировании.** Флаг отмены только не даёт обновить
  состояние; в dev-режиме (StrictMode) уходят два запроса. Почему отложено: запрос дешёвый, вреда нет, код
  соответствует плану. Когда вернуться: если появятся запросы, которые дорого повторять, — `AbortController`
  и `api.GET(..., { signal })`, отмену в `catch` игнорировать.
- **P1 — нет автоматической проверки, что стили Tailwind/shadcn применились.** Риск назван в спеке 5.2 (обёртка
  next-intl может затереть `turbopack.rules`), но защищает от него только ручная проверка владельца. Почему отложено:
  это изменение плана и спеки. Когда вернуться: при первом изменении `next.config.ts` или обновлении Next.js /
  next-intl; вариант — e2e-проверка `toHaveCSS` шрифта Geist или цвета метки. До этого стили проверяются вручную
  (см. «Завершение этапа 2»).
