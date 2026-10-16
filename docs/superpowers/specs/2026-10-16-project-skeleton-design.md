# Скелет проекта «Система управления складом» — дизайн

Дата: 2026-10-16. Ветка: `feature/skeleton`.

## 1. Цель

Создать фундамент проекта без бизнес-логики и авторизации: бэкенд (FastAPI + PostgreSQL), фронтенд (Next.js),
локальная БД в Docker, единый скрипт проверок, e2e-тесты, CI и документация. Всё дальнейшее (каталог, склады,
остатки, пользователи) строится поверх этого скелета.

**Критерии готовности:**

1. `docker compose up -d` поднимает PostgreSQL с базами `wms_crm` и `wms_crm_test`.
2. `./scripts/check.sh` — зелёный.
3. `npm run test:e2e` (в `frontend/`) — зелёный.
4. CI на Pull Request — зелёный.
5. Команды из раздела «Команды» корневого `CLAUDE.md` работают ровно так, как там написано.

**Не входит (YAGNI):** модели предметной области, авторизация, CORS, переключатель языка в интерфейсе,
Docker-образы бэкенда и фронтенда, деплой, pre-commit-хуки.

## 2. Структура репозитория

```
wms-crm/
├── backend/                          # uv-проект, Python 3.13 (.python-version)
│   ├── app/
│   │   ├── main.py
│   │   ├── export_openapi.py
│   │   ├── core/        config.py, db.py
│   │   ├── models/      __init__.py, base.py
│   │   ├── schemas/     health.py
│   │   ├── services/    health.py
│   │   └── api/         router.py, routes/health.py
│   ├── alembic/         env.py, script.py.mako, versions/
│   ├── tests/           conftest.py, test_health.py, test_export_openapi.py
│   ├── alembic.ini, pyproject.toml, uv.lock, .python-version
│   ├── .env.example
│   └── CLAUDE.md
├── frontend/                         # Next.js 16, Node 24 (.nvmrc)
│   ├── messages/        ru.json, en.json
│   ├── e2e/             home.spec.ts, global-teardown.ts
│   ├── src/
│   │   ├── app/         layout.tsx, page.tsx, globals.css
│   │   ├── components/  backend-status.tsx, ui/ (card, badge)
│   │   ├── i18n/        config.ts, request.ts, messages.test.ts
│   │   ├── lib/         utils.ts, backend-status.ts, backend-status.test.ts, api/client.ts, api/schema.d.ts
│   │   └── global.d.ts
│   ├── openapi.json
│   ├── next.config.ts, tsconfig.json, eslint.config.mjs, .prettierrc, .prettierignore
│   ├── vitest.config.mts, playwright.config.ts, components.json
│   ├── package.json, package-lock.json, .nvmrc, .gitignore
│   ├── .env.example
│   └── CLAUDE.md
├── docker/postgres/init/01-create-databases.sql
├── scripts/check.sh                  # исполняемый бит
├── .github/workflows/ci.yml
├── docs/ROADMAP.md
├── docs/superpowers/{specs,plans}/
├── docker-compose.yml
├── .env.example                      # для docker compose
├── .gitattributes                    # + *.sh text eol=lf
├── README.md
└── CLAUDE.md
```

## 3. Окружение

### 3.1. docker-compose.yml

Только сервис `db`:

- образ `postgres:18`;
- порт `127.0.0.1:5432:5432` — БД не видна из сети;
- `POSTGRES_USER=${POSTGRES_USER:-postgres}`, `POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}`, `POSTGRES_DB` не задаётся;
- именованный том `pgdata:/var/lib/postgresql` (с версии 18 образ объявляет том именно здесь, а не в `.../data`);
- `./docker/postgres/init:/docker-entrypoint-initdb.d:ro`;
- healthcheck: `pg_isready -h localhost -U $${POSTGRES_USER} -d wms_crm_test`, интервал 5 с.
  Флаг `-h` заставляет проверять TCP: без него проверка может пройти на временном сервере,
  который образ запускает на время init-скриптов, до создания БД.

### 3.2. Init-скрипт

`docker/postgres/init/01-create-databases.sql`:

```sql
CREATE DATABASE wms_crm;
CREATE DATABASE wms_crm_test;
```

Срабатывает только на пустом томе. Пересоздать БД: `docker compose down -v && docker compose up -d`.

### 3.3. Переменные окружения

Без `.env` всё работает на значениях по умолчанию (`postgres` / `postgres`).

| Файл | Переменная | По умолчанию |
|---|---|---|
| `.env.example` (корень) | `POSTGRES_USER`, `POSTGRES_PASSWORD` | `postgres`, `postgres` |
| `backend/.env.example` | `DATABASE_URL` | `postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm` |
| | `TEST_DATABASE_URL` | `postgresql+psycopg://postgres:postgres@localhost:5432/wms_crm_test` |
| | `USE_TEST_DATABASE` | `false` |
| `frontend/.env.example` | `BACKEND_URL` | `http://localhost:8000` |

В комментариях `.env.example` и в README: при смене пароля его нужно поменять в корневом `.env` и в обоих
адресах БД в `backend/.env`, затем пересоздать том (`docker compose down -v`).

Все `.env.example` не должны попадать под шаблоны игнорирования (`create-next-app` добавляет `.env*` — нужен
`!.env.example`). Проверка: `git check-ignore .env.example backend/.env.example frontend/.env.example` ничего не выводит.

### 3.4. Порты

| Режим | Бэкенд | Фронтенд | БД |
|---|---|---|---|
| разработка | 8000 → `wms_crm` | 3000, `next dev` (`.next/dev`) | 5432 |
| e2e | 8001 → `wms_crm_test` | 3001, `next build` + `next start` (`.next-e2e`) | 5432 |

Почему e2e на production-сборке в отдельной папке:

- Next.js 16 ставит замок `.next/dev/lock` — второй `next dev` из той же папки не запустится;
- `next build` в стандартную `.next` оставил бы там сборку, собранную для e2e (правила rewrites с адресом 8001
  записываются в `routes-manifest.json` при сборке). Поэтому e2e собирается в `.next-e2e` (`NEXT_DIST_DIR`).

`.gitattributes` дополняется правилом `*.sh text eol=lf`.

## 4. Бэкенд

### 4.1. Зависимости

Основные (`uv add`):

- `fastapi` — веб-фреймворк;
- `uvicorn[standard]` — ASGI-сервер;
- `sqlalchemy` — ORM, синхронный режим;
- `psycopg[binary]` — драйвер PostgreSQL 3 (binary — без системной libpq);
- `alembic` — миграции;
- `pydantic` — схемы (используем напрямую, поэтому объявлен явно);
- `pydantic-settings` — настройки из окружения и `.env`.

Dev-группа (`uv add --dev`): `pytest`, `ruff`, `mypy`, `httpx` (нужен для `fastapi.testclient.TestClient`).

### 4.2. Настройки (`app/core/config.py`)

- `Settings(BaseSettings)`: `database_url`, `test_database_url`, `use_test_database: bool = False`
  (значения по умолчанию — из таблицы 3.3).
- Путь к `.env` вычисляется от файла: `Path(__file__).resolve().parents[2] / ".env"` (папка `backend/`),
  поэтому настройки одинаковы, откуда бы ни запускали uvicorn, Alembic или pytest. Отсутствие файла — не ошибка.
- Свойство `effective_database_url` — единственное место выбора адреса: `test_database_url`, если
  `use_test_database`, иначе `database_url`. Его используют `engine` и `alembic/env.py`.
- `get_settings()` с `functools.lru_cache`.

### 4.3. БД (`app/core/db.py`, `app/models/`)

- `engine = create_engine(settings.effective_database_url, pool_pre_ping=True, connect_args={"connect_timeout": 3})`.
  Таймаут подключения 3 с — health не зависает при недоступной БД.
- `SessionLocal = sessionmaker(bind=engine)`; зависимость `get_db()` отдаёт сессию и закрывает её.
- `app/models/base.py`: `class Base(DeclarativeBase)` с `metadata = MetaData(naming_convention=...)`:
  `ix`, `uq`, `ck`, `fk`, `pk` — стандартные шаблоны SQLAlchemy.
- `app/models/__init__.py` реэкспортирует `Base` (и в будущем все модели — чтобы их видел Alembic).

### 4.4. Health

- `app/schemas/health.py`: `HealthResponse(status: Literal["ok", "error"], db: Literal["ok", "error"])`.
- `app/services/health.py`: `is_database_available(session: Session) -> bool` — `SELECT 1`;
  `SQLAlchemyError` → `False`.
- `app/api/routes/health.py`: `GET /health` — обычный `def`. `True` → 200 `{"status": "ok", "db": "ok"}`;
  `False` → 503 `{"status": "error", "db": "error"}`. В OpenAPI описаны оба ответа (`responses={503: ...}`).
- `app/api/router.py` собирает роутеры; `app/main.py` создаёт `app = FastAPI(...)` и подключает роутер
  с префиксом `/api`. Итоговый адрес — `GET /api/health`.

### 4.5. Выгрузка OpenAPI

`python -m app.export_openapi <путь>` — пишет `app.openapi()` в JSON (`indent=2`, `ensure_ascii=False`,
перевод строки в конце). Сервер и БД не нужны. Вывод детерминирован — на этом построена проверка в CI.

### 4.6. Alembic

- Миграции в `backend/alembic/`; в `alembic.ini` адреса БД нет.
- `env.py`: адрес — `config.attributes.get("database_url")` (передают тесты), иначе
  `get_settings().effective_database_url`. Поэтому `USE_TEST_DATABASE=true uv run alembic upgrade head`
  работает с `wms_crm_test`. `target_metadata = app.models.Base.metadata`.
- Имена файлов миграций начинаются с даты и времени (`file_template`), новые миграции форматируются ruff
  (`post_write_hooks`).
- Моделей пока нет — миграций нет; `alembic upgrade head` проходит без изменений.

### 4.7. Инструменты (`pyproject.toml`)

- ruff: `line-length = 100`, правила `E`, `F`, `I`, `UP`, `B`, `SIM`; `target-version = "py313"`.
- mypy: `strict = true`, плагин `pydantic.mypy`; проверяется `app` (`uv run mypy app`).
- pytest: `testpaths = ["tests"]`.

## 5. Фронтенд

### 5.1. Создание и зависимости

Проект создаётся `create-next-app` (TypeScript, Tailwind CSS, ESLint, App Router, `src/`, алиас `@/*`, npm).
`.nvmrc` = `24` (актуальная LTS). `tsconfig.json` — `strict`.

| Пакет | Тип | Зачем |
|---|---|---|
| `next-intl` | основная | переводы ru/en |
| `openapi-fetch` | основная | типизированный HTTP-клиент по сгенерированным типам |
| `openapi-typescript` | dev | генерация TS-типов из `openapi.json` |
| `prettier`, `eslint-config-prettier` | dev | форматирование; отключение конфликтующих правил ESLint |
| `vitest` | dev | unit-тесты чистой логики |
| `@playwright/test` | dev | e2e-тесты (Chromium) |
| shadcn/ui `card`, `badge` | код в `src/components/ui` | карточка статуса и метка; зависимости, которые ставит `shadcn init`, перечисляются в плане |

### 5.2. Конфигурация

- `next.config.ts`:
  - `distDir: process.env.NEXT_DIST_DIR ?? ".next"`;
  - rewrite `/api/:path*` → `${process.env.BACKEND_URL ?? "http://localhost:8000"}/api/:path*`;
  - обёртка `createNextIntlPlugin()`.
- `tsconfig.json`: в `include` заранее добавлен `.next-e2e/types/**/*.ts`, чтобы `next build` для e2e не менял файл.
- `.gitignore` фронта: `!.env.example`, `.next-e2e/`.
- `eslint.config.mjs`: конфиг Next.js + `eslint-config-prettier`; `globalIgnores`: `.next/`, `.next-e2e/`, `out/`,
  `build/`, `next-env.d.ts`, `playwright-report/`, `test-results/`, `blob-report/`, `src/lib/api/schema.d.ts`.
- `.prettierignore`: сборки, отчёты Playwright, `openapi.json`, `src/lib/api/schema.d.ts`
  (сгенерированные файлы не форматируются, иначе проверка свежести в CI конфликтует с `format:check`).

### 5.3. Переводы (next-intl без языка в адресе)

- `messages/ru.json`, `messages/en.json` — ключи `Metadata.title`, `HomePage.title`,
  `BackendStatus.checking`, `BackendStatus.ok`, `BackendStatus.unavailable`.

  | Ключ | ru | en |
  |---|---|---|
  | `Metadata.title`, `HomePage.title` | Система управления складом | Warehouse Management System |
  | `BackendStatus.checking` | Бэкенд: проверка… | Backend: checking… |
  | `BackendStatus.ok` | Бэкенд: работает | Backend: running |
  | `BackendStatus.unavailable` | Бэкенд: недоступен | Backend: unavailable |

- `src/i18n/config.ts`: `locales = ["ru", "en"] as const`, `defaultLocale = "ru"`.
- `src/i18n/request.ts`: `getRequestConfig` всегда возвращает `defaultLocale` и его сообщения.
- `src/global.d.ts`: типизация ключей next-intl по `ru.json` (опечатка в ключе — ошибка `tsc`).
- `src/app/layout.tsx`: `<html lang={locale}>`, `NextIntlClientProvider`, `generateMetadata` с `Metadata.title`.

### 5.4. API-клиент и статус бэкенда

- `npm run gen:api` = `uv run --directory ../backend python -m app.export_openapi ../frontend/openapi.json && openapi-typescript openapi.json -o src/lib/api/schema.d.ts`.
  `openapi.json` и `schema.d.ts` коммитятся.
- `src/lib/api/client.ts`: `createClient<paths>(...)` из openapi-fetch; браузер обращается по относительному пути
  `/api/...` (способ задания `baseUrl` — по документации openapi-fetch).
- `src/lib/backend-status.ts`: чистая функция `resolveBackendStatus(result)`, где `result` — либо HTTP-статус ответа,
  либо признак сетевой ошибки. 200 → `"ok"`; любой другой статус или сетевая ошибка → `"unavailable"`.
- `src/components/backend-status.tsx` (`"use client"`): начальное состояние `"checking"`; в `useEffect` —
  `api.GET("/api/health")` внутри `try/catch` (при обрыве сети openapi-fetch бросает исключение, а не возвращает
  `error`); результат → `resolveBackendStatus`. Текст — из переводов, в `Badge` с `aria-live="polite"`.
- `src/app/page.tsx` (серверный компонент): `<h1>` из `HomePage.title` и `Card` с `<BackendStatus />`.

### 5.5. Скрипты `package.json`

| Скрипт | Команда |
|---|---|
| `dev`, `build`, `start` | стандартные Next.js |
| `lint` | `eslint .` |
| `format` / `format:check` | `prettier --write .` / `prettier --check .` |
| `typecheck` | `next typegen && tsc --noEmit` (типы Next.js без сборки — работает и в CI) |
| `test` | `vitest run` |
| `test:e2e` | `playwright test` |
| `gen:api` | см. 5.4 |

## 6. Тесты

### 6.1. Бэкенд (pytest, строгий TDD)

`tests/conftest.py`:

- В начале прогона (фикстура уровня сессии): проверка, что имя БД в `TEST_DATABASE_URL` оканчивается на `_test`
  (иначе — остановка с понятной ошибкой); `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`;
  `alembic upgrade head` с `config.attributes["database_url"] = TEST_DATABASE_URL`.
  Так изменённая миграция или данные от e2e не влияют на тесты.
- `db_session` (на каждый тест): соединение → `BEGIN` →
  `Session(bind=connection, join_transaction_mode="create_savepoint")` → после теста `ROLLBACK`.
  Даже `session.commit()` в коде не сохраняет данные.
- `client`: `TestClient(app)` с `app.dependency_overrides[get_db]`, отдающим `db_session`.

Тесты:

1. `GET /api/health` при доступной БД → 200, `{"status": "ok", "db": "ok"}`.
2. `GET /api/health` при недоступной БД → 503, `{"status": "error", "db": "error"}`, ответ быстрее 5 с.
   `get_db` подменяется сессией на движке с адресом `10.255.255.1` (пакеты теряются) и тем же `connect_timeout=3`.
3. `export_openapi` пишет файл, в нём есть путь `/api/health`.

pytest и e2e используют одну `wms_crm_test` — одновременно их не запускать (указано в README).

### 6.2. Фронтенд, Vitest (окружение `node`, файлы `src/**/*.test.ts`)

1. `src/lib/backend-status.test.ts`: 200 → `ok`; 503 → `unavailable`; сетевая ошибка → `unavailable`.
2. `src/i18n/messages.test.ts`: набор ключей `ru.json` и `en.json` совпадает
   (вложенные ключи разворачиваются в плоский список `BackendStatus.ok` и т. п.).

### 6.3. Фронтенд, Playwright (`frontend/playwright.config.ts`, `frontend/e2e/`)

- Только Chromium, `baseURL: http://localhost:3001`, в CI — 1 повтор.
- `webServer` (оба с `reuseExistingServer: false`):

  | Сервер | Команда | Окружение | Готовность |
  |---|---|---|---|
  | бэкенд | `uv run --directory ../backend alembic upgrade head && uv run --directory ../backend uvicorn app.main:app --port 8001` | `USE_TEST_DATABASE=true` | `http://localhost:8001/api/health`, до 60 с |
  | фронт | `npm run build && npm run start -- -p 3001` | `NEXT_DIST_DIR=.next-e2e`, `BACKEND_URL=http://localhost:8001` | `http://localhost:3001`, до 180 с |

- `e2e/home.spec.ts` (ожидаемые тексты — по-русски прямо в тесте):
  1. Реальный стек: виден заголовок «Система управления складом» и текст «Бэкенд: работает».
  2. `page.route("**/api/health")` → `fulfill` со статусом 503 → «Бэкенд: недоступен».
  3. `page.route("**/api/health")` → `abort()` (обрыв соединения) → «Бэкенд: недоступен».
- `globalTeardown` (`e2e/global-teardown.ts`) после прогона удаляет `.next-e2e`: сборка всё равно каждый раз новая,
  а устаревшие типы из `.next-e2e/types` (папка в `include` tsconfig) могли бы ломать `typecheck` после удаления
  или переименования страниц.
- Нужна только запущенная БД. Если запущен dev-сервер на 3000, e2e ему не мешает
  (`.next/dev` и `.next-e2e` — разные папки). После e2e `git status` чист, папки `.next-e2e` нет.

## 7. scripts/check.sh

1. Bash; корень проекта вычисляется от расположения скрипта — запускается из любой папки.
2. Предусловия (при невыполнении — подсказка и выход с кодом 1, проверки не запускаются):
   - БД доступна: короткий Python-код через `uv run` подключается к `TEST_DATABASE_URL` из настроек бэкенда
     (учитывает `backend/.env`). Подсказка: «запусти `docker compose up -d` в корне проекта; если контейнер
     только что создан — подожди несколько секунд»;
   - есть `frontend/node_modules`, иначе подсказка «выполни `npm ci` в папке frontend/».
3. Проверки — все по очереди, падение одной не останавливает остальные:
   1. `ruff check .`
   2. `ruff format --check .`
   3. `mypy app`
   4. `pytest`
   5. `alembic check` — `USE_TEST_DATABASE=true`: сначала `alembic upgrade head`, затем `alembic check`
      (ловит изменённые модели без миграции)
   6. `npm run lint`
   7. `npm run format:check`
   8. `npm run typecheck`
   9. `npm run test`
4. Сводка: каждая проверка — OK или FAIL; код выхода 1, если упала хоть одна. e2e в скрипт не входит.

## 8. CI (`.github/workflows/ci.yml`)

- Запуск: `pull_request` и `push` в `main`. `permissions: contents: read`.
  `concurrency` — новый прогон той же ветки отменяет старый.
- Зависимости строго по lock-файлам: `uv sync --locked`, `npm ci`.
- Версии actions (`checkout`, `setup-node`, `astral-sh/setup-uv`, `upload-artifact`) — актуальные мажорные,
  сверяются при написании плана.

| Задание | Шаги |
|---|---|
| `backend` | сервис `postgres:18` (`POSTGRES_USER/PASSWORD=postgres`, `POSTGRES_DB=wms_crm_test` — тестовая БД создаётся настройками сервиса, healthcheck через `pg_isready`, порт 5432); checkout, setup-uv (Python из `.python-version`), `uv sync --locked`, `ruff check .`, `ruff format --check .`, `mypy app`, `pytest`, `alembic upgrade head` + `alembic check` с `USE_TEST_DATABASE=true` |
| `frontend` | setup-node (`node-version-file: frontend/.nvmrc`, кэш npm), `npm ci`, lint, format:check, typecheck, test; проверка свежести типов API: setup-uv, `uv sync --locked` в `backend/`, `npm run gen:api`, `git diff --exit-code -- frontend/openapi.json frontend/src/lib/api/schema.d.ts` |
| `e2e` | тот же сервис Postgres; setup-uv + `uv sync --locked`, setup-node + `npm ci`, `npx playwright install --with-deps chromium`, `npm run test:e2e`; при падении — `playwright-report` выгружается артефактом |

## 9. Документация

- **README.md** (по-русски): требования (Docker, uv, Node 24 через nvm); запуск с нуля по шагам; все команды;
  e2e (порты 8001/3001, не запускать одновременно с pytest); смена пароля БД; пересоздание БД
  (`docker compose down -v` — init-скрипт срабатывает только на пустом томе); структура проекта.
- **backend/CLAUDE.md** (коротко): команды; эндпоинты с БД — обычный `def`; адрес БД — только через
  `effective_database_url`; модели наследуют `Base` и реэкспортируются в `app/models/__init__.py`;
  миграции — `alembic revision --autogenerate`, автосгенерированную миграцию всегда просматривать
  (переименование колонки autogenerate видит как удаление и создание — исправлять вручную на `op.alter_column`);
  после изменения эндпоинтов или схем — `npm run gen:api` в `frontend/` и закоммитить `openapi.json` и `schema.d.ts`;
  тесты — через фикстуры `client` и `db_session`.
- **frontend/CLAUDE.md** (коротко): команды; тексты интерфейса — только в `messages/*.json` (ru и en);
  запросы — через `src/lib/api/client.ts`; после изменения API — `npm run gen:api`; компоненты — `npx shadcn add`;
  Vitest — только чистая логика (`src/lib`, `src/i18n`); e2e — в `e2e/`.
- **docs/ROADMAP.md**: только модули и статусы. Скелет проекта — «в работе» (в конце ветки — «готово»);
  пользователи и роли, каталог товаров, склады, остатки и движения, переключение языка ru/en — «запланировано».

## 10. Этапы реализации

Порядок завершения каждого этапа:

1. В конце этапа — список команд, которыми владелец проверяет результат (с ожидаемым результатом каждой).
2. Владелец проверяет, затем коммит (после подтверждения).
3. После коммита — остановка до команды владельца на следующий этап.

Этапы:

1. **Бэкенд + БД:** `docker-compose.yml`, init-скрипт, корневой `.env.example`, `.gitattributes`, весь `backend/`
   (включая выгрузку OpenAPI, Alembic и тесты).
2. **Фронтенд:** проект Next.js, next-intl, shadcn/ui, API-клиент и `gen:api`, главная страница, Vitest.
3. **Проверки:** `scripts/check.sh`, Playwright и e2e-тесты.
4. **CI и документация:** `ci.yml`, README, `backend/CLAUDE.md`, `frontend/CLAUDE.md`, `docs/ROADMAP.md`.
   Затем push и PR (после подтверждения) и зелёный CI.

## 11. Что сверить с документацией (Context7) при написании плана

- флаги `create-next-app` для Next.js 16 и состав создаваемых файлов;
- `shadcn init` для Next.js 16 / Tailwind CSS 4 и добавляемые им зависимости;
- `baseUrl` openapi-fetch для относительных путей в браузере; поведение при сетевой ошибке;
- next-intl: настройка без i18n-маршрутизации и типизация `AppConfig`;
- `next typegen` и `include` в `tsconfig.json` при своём `distDir`;
- Playwright: массив `webServer`, запуск команды через shell (`&&`), `page.route` / `abort`, `globalTeardown`
  (выполняется ли до или после остановки `webServer`);
- SQLAlchemy 2.0: `join_transaction_mode="create_savepoint"`; pydantic-settings: `env_file`;
- Alembic: `config.attributes` в `env.py`, `file_template`, ruff в `post_write_hooks`, `alembic check`;
- GitHub Actions: сервис-контейнеры, `astral-sh/setup-uv`, `actions/setup-node` с `node-version-file`.
