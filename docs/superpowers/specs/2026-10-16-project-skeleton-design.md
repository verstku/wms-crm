# Скелет проекта «Система управления складом» — дизайн

Дата: 2026-10-16, обновлено 2026-10-17 по итогам ревью. Ветка: `feature/skeleton`.

## 1. Цель

Создать фундамент проекта без бизнес-логики и авторизации: бэкенд (FastAPI + PostgreSQL), фронтенд (Next.js),
локальная БД в Docker, единый скрипт проверок, e2e-тесты, CI и документация. Всё дальнейшее (каталог, склады,
остатки, пользователи) строится поверх этого скелета.

**Критерии готовности:**

1. `docker compose up -d --wait` на пустом томе завершается с кодом 0, сервис `db` — в состоянии `healthy`,
   а `docker compose exec db psql -U postgres -lqt` выводит базы `wms_crm` и `wms_crm_test`.
2. `./scripts/check.sh` — зелёный.
3. `npm run test:e2e` (в `frontend/`) — зелёный; после него `git status` чист, папки `frontend/.next-e2e` нет.
4. CI на Pull Request — зелёный.
5. Каждая команда из раздела «Команды» корневого `CLAUDE.md` даёт результат из таблицы 1.1.

**Не входит (YAGNI):** модели предметной области, авторизация, CORS, переключатель языка в интерфейсе,
Docker-образы бэкенда и фронтенда, деплой, pre-commit-хуки.

### 1.1. Проверка команд из корневого CLAUDE.md

| Команда (папка) | Как проверить | Ожидаемый результат |
|---|---|---|
| `docker compose up -d --wait` (корень) | выполнить, затем `docker compose ps` | код 0, `db` — `healthy` |
| `uv run uvicorn app.main:app --reload --port 8000` (`backend/`) | в другом терминале `curl -i http://localhost:8000/api/health`, затем Ctrl+C | `200`, `{"status":"ok","db":"ok"}` |
| `uv run pytest` (`backend/`) | выполнить | все тесты зелёные |
| `uv run ruff check . && uv run ruff format --check . && uv run mypy app` (`backend/`) | выполнить | код 0 |
| `uv run alembic upgrade head` (`backend/`) | выполнить | код 0 (миграций пока нет) |
| `uv run alembic revision --autogenerate -m "check template"` (`backend/`) | выполнить; затем `uv run ruff check .` и `uv run ruff format --check .`; затем удалить созданный файл | файл в `alembic/versions/`, имя начинается с даты и времени; ruff зелёный; после удаления `git status` чист |
| `npm run dev` (`frontend/`, бэкенд на 8000 запущен) | открыть http://localhost:3000, затем Ctrl+C | заголовок «Система управления складом» и текст «Бэкенд: работает» |
| `npm run lint && npm run format:check && npm run typecheck` (`frontend/`) | выполнить | код 0 |
| `npm run test` (`frontend/`) | выполнить | все тесты зелёные |
| `npm run test:e2e` (`frontend/`) | выполнить, затем `git status` | все тесты зелёные; изменений нет, папки `.next-e2e` нет |
| `npm run gen:api` (`frontend/`, бэкенд не запущен) | выполнить, затем `git status` | код 0; изменений нет (типы свежие) |
| `./scripts/check.sh` (из любой папки) | выполнить | все проверки OK, код 0 |

## 2. Структура репозитория

```
wms-crm/
├── backend/                          # uv-проект без сборки пакета, Python 3.13 (.python-version)
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
│   │   └── global.ts
│   ├── openapi.json
│   ├── next.config.ts, tsconfig.json, eslint.config.mjs, postcss.config.mjs, .prettierrc, .prettierignore
│   ├── vitest.config.mts, playwright.config.ts, components.json
│   ├── package.json, package-lock.json, .nvmrc, .gitignore
│   ├── .env.example
│   ├── AGENTS.md                     # создаёт create-next-app, не редактируем
│   └── CLAUDE.md                     # строка «@AGENTS.md» + наши правила
├── docker/postgres/init/01-create-databases.sql
├── scripts/check.sh                  # исполняемый бит
├── .github/workflows/ci.yml
├── docs/ROADMAP.md
├── docs/superpowers/{specs,plans}/
├── docker-compose.yml
├── .env.example                      # для docker compose
├── .gitignore                        # + .tmp/ (временные файлы check.sh)
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
- healthcheck в форме `CMD-SHELL` (иначе `$${POSTGRES_USER}` не раскроется): `pg_isready -h localhost -U $${POSTGRES_USER}`;
  `interval: 5s`, `timeout: 5s`, `start_period: 30s`, `retries: 10`.
  - Флаг `-h` заставляет проверять TCP. На время init-скриптов образ запускает временный сервер, который слушает
    только unix-сокет; TCP-подключения сервер принимает только после init-скриптов, то есть когда обе БД уже созданы.
    Флаг `-d` не нужен: `pg_isready` не проверяет, существует ли база.
  - `start_period` и `retries` — запас на медленный первый запуск (создание кластера и баз): неудачные проверки
    в первые 30 с не считаются, а `unhealthy` контейнер станет только после 10 неудач подряд. Поэтому
    `docker compose up -d --wait` не падает на первом запуске.

### 3.2. Init-скрипт

`docker/postgres/init/01-create-databases.sql`:

```sql
CREATE DATABASE wms_crm;
CREATE DATABASE wms_crm_test;
```

Срабатывает только на пустом томе. Пересоздать БД: `docker compose down -v && docker compose up -d --wait`.

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
`!.env.example`). Проверка: `git check-ignore --no-index .env.example backend/.env.example frontend/.env.example`
ничего не выводит. Флаг `--no-index` обязателен: к уже закоммиченным файлам git правила игнорирования
не применяет, и без флага вывод пуст всегда.

### 3.4. Порты

| Режим | Бэкенд | Фронтенд | БД |
|---|---|---|---|
| разработка | 8000 → `wms_crm` | 3000, `next dev` (`.next/dev`) | 5432 |
| e2e | 8001 → `wms_crm_test` | 3001, `next build` + `next start` (`.next-e2e`) | 5432 |

Почему e2e на production-сборке в отдельной папке:

- Next.js 16 ставит замок `.next/dev/lock` — второй `next dev` из той же папки не запустится;
- `next build` в стандартную `.next` оставил бы там сборку, собранную для e2e (правила rewrites с адресом 8001
  записываются в `routes-manifest.json` при сборке). Поэтому e2e собирается в `.next-e2e` (`NEXT_DIST_DIR`).

## 4. Бэкенд

### 4.1. Создание и зависимости

Проект создаётся командой `uv init --bare --name wms-crm-backend --python 3.13` — только `pyproject.toml`:
без папки `src/`, без `main.py` и `README.md`, без сборки пакета (проект не устанавливается в окружение как пакет).
Затем `uv python pin 3.13` создаёт `.python-version`. Обычный `uv init` не подходит: в uv 0.13 он (даже с `--app`)
создаёт пакет с раскладкой `src/<имя>/` и сборщиком `uv_build`, а у нас пакет — `backend/app/`.

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
- `extra="ignore"`: по умолчанию pydantic-settings запрещает лишние переменные и в `.env` — любая посторонняя
  строка в `backend/.env` роняла бы запуск с `ValidationError`.
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
перевод строки в конце). Сервер и БД не нужны. Вывод детерминирован — на этом построены проверки свежести типов
в `check.sh` и в CI.

### 4.6. Alembic

- Миграции в `backend/alembic/`; в `alembic.ini` адреса БД нет.
- `env.py`: адрес — `config.attributes.get("database_url")` (передают тесты), иначе
  `get_settings().effective_database_url`. Поэтому `USE_TEST_DATABASE=true uv run alembic upgrade head`
  работает с `wms_crm_test`. `target_metadata = app.models.Base.metadata`.
- Имена файлов миграций начинаются с даты и времени (`file_template`).
- `post_write_hooks` (команды, которые Alembic запускает после создания файла миграции) — по порядку:
  `ruff check --fix`, затем `ruff format`; тип хука `module`, модуль `ruff` (есть с Alembic 1.16.3).
  Одного форматирования мало: стандартный шаблон `script.py.mako` использует `typing.Sequence`/`Union`
  и неотсортированные импорты — это ошибки `ruff check` (UP035, UP007, I001, у пустой миграции ещё F401),
  которые `ruff format` не исправляет, а `ruff check --fix` исправляет все.
- Моделей пока нет — миграций нет; `alembic upgrade head` проходит без изменений.

### 4.7. Инструменты (`pyproject.toml`)

- ruff: `line-length = 100`, правила `E`, `F`, `I`, `UP`, `B`, `SIM`; `target-version = "py313"`.
- mypy: `strict = true`, плагин `pydantic.mypy`; проверяется `app` (`uv run mypy app`).
- pytest: `testpaths = ["tests"]`, `pythonpath = ["."]`. Без `pythonpath` pytest не находит пакет `app`
  (`ModuleNotFoundError`): проект не устанавливается как пакет, а в `tests/` нет `__init__.py`.

## 5. Фронтенд

### 5.1. Создание и зависимости

Проект создаётся `create-next-app` (TypeScript, Tailwind CSS, ESLint, App Router, `src/`, алиас `@/*`, npm).
`.nvmrc` = `24` (актуальная LTS). `tsconfig.json` — `strict`.

`create-next-app` (с Next.js 16.2) по умолчанию создаёт ещё два файла: `AGENTS.md` — инструкцию агентам читать
документацию Next.js из `node_modules/next/dist/docs/` (она совпадает с установленной версией), и `CLAUDE.md`
со строкой `@AGENTS.md`. Оба файла оставляем: `AGENTS.md` не редактируем, наши правила дописываются
в `frontend/CLAUDE.md` под строкой `@AGENTS.md` (раздел 9).

Ненужные файлы шаблона удаляются: `frontend/README.md` (README в проекте один — корневой, на русском)
и картинки в `public/`, которые использовала стартовая страница шаблона.

| Пакет | Тип | Зачем |
|---|---|---|
| `next-intl` | основная | переводы ru/en |
| `openapi-fetch` | основная | типизированный HTTP-клиент по сгенерированным типам |
| `openapi-typescript` | dev | генерация TS-типов из `openapi.json` |
| `prettier`, `eslint-config-prettier` | dev | форматирование; отключение конфликтующих правил ESLint |
| `vitest` | dev | unit-тесты чистой логики |
| `@playwright/test` | dev | e2e-тесты (Chromium) |
| shadcn/ui `card`, `badge` | код в `src/components/ui` | карточка статуса и метка; зависимости, которые ставит `shadcn init`, перечисляются в плане |

shadcn/ui инициализируется с библиотекой компонентов **Base UI**: `shadcn init --base base --template next
--no-monorepo`. Без `--base` или `--preset` команда останавливается на интерактивном вопросе даже с `-y`.
Стиль (пресет) выбирается в плане.

### 5.2. Конфигурация

- `next.config.ts`:
  - `distDir: process.env.NEXT_DIST_DIR ?? ".next"`;
  - rewrite `/api/:path*` → `${process.env.BACKEND_URL ?? "http://localhost:8000"}/api/:path*`;
  - обёртка `createNextIntlPlugin()`.
- `tsconfig.json`: в `include` заранее добавлены `.next-e2e/types/**/*.ts` и `.next-e2e/dev/types/**/*.ts`.
  `next build` с `distDir=.next-e2e` требует оба пути (свои типы и типы dev-режима) и, если какого-то нет,
  перезаписывает `tsconfig.json` — тогда после e2e `git status` был бы не чист.
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
- `src/global.ts`: типизация next-intl через `AppConfig` (`Locale` — из `locales`, `Messages` — по `ru.json`);
  опечатка в ключе — ошибка `tsc`. Файл именно `.ts`, а не `.d.ts`: при `skipLibCheck: true` (так настраивает
  `create-next-app`) ошибки внутри `.d.ts` не показываются — неверный путь к `ru.json` молча превратил бы тип
  в `any`, и опечатки в ключах перестали бы ловиться.
- Проверка в конце этапа 2: временная опечатка в ключе перевода в `page.tsx` → `npm run typecheck` падает;
  опечатку убрать.
- `src/app/layout.tsx`: `<html lang={locale}>`, `NextIntlClientProvider`, `generateMetadata` с `Metadata.title`.

### 5.4. API-клиент и статус бэкенда

- `npm run gen:api` = `uv run --directory ../backend python -m app.export_openapi ../frontend/openapi.json && openapi-typescript openapi.json -o src/lib/api/schema.d.ts`.
  `openapi.json` и `schema.d.ts` коммитятся.
- `src/lib/api/client.ts`: `createClient<paths>(...)` из openapi-fetch; браузер обращается по относительному пути
  `/api/...` (`baseUrl` не задаётся).
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

- В начале прогона (фикстура уровня сессии): тестовый движок создаётся от `TEST_DATABASE_URL` из настроек;
  проверка, что имя БД в этом адресе оканчивается на `_test` (иначе — остановка с понятной ошибкой);
  `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`;
  `alembic upgrade head` с `config.attributes["database_url"] = TEST_DATABASE_URL`.
  Так изменённая миграция или данные от e2e не влияют на тесты.
- `db_session` (на каждый тест): соединение от тестового движка → `BEGIN` →
  `Session(bind=connection, join_transaction_mode="create_savepoint")` → после теста `ROLLBACK`.
  Даже `session.commit()` в коде не сохраняет данные.
- `client`: `TestClient(app)` с `app.dependency_overrides[get_db]`, отдающим `db_session`.
- `engine` из `app/core/db.py` в тестах не используется: он смотрит на `effective_database_url`, а в pytest
  это `wms_crm` (`USE_TEST_DATABASE=false`).

Тесты:

1. `GET /api/health` при доступной БД → 200, `{"status": "ok", "db": "ok"}`.
2. `GET /api/health` при недоступной БД → 503, `{"status": "error", "db": "error"}`, ответ быстрее 5 с.
   `get_db` подменяется сессией на движке с адресом `10.255.255.1` (пакеты теряются) и тем же `connect_timeout=3`.
3. `export_openapi` пишет файл, в нём есть путь `/api/health`.

pytest и e2e используют одну `wms_crm_test` — одновременно их не запускать (указано в README и в корневом
`CLAUDE.md`).

### 6.2. Фронтенд, Vitest (окружение `node`, файлы `src/**/*.test.ts`)

1. `src/lib/backend-status.test.ts`: 200 → `ok`; 503 → `unavailable`; сетевая ошибка → `unavailable`.
2. `src/i18n/messages.test.ts`: набор ключей `ru.json` и `en.json` совпадает
   (вложенные ключи разворачиваются в плоский список `BackendStatus.ok` и т. п.).

### 6.3. Фронтенд, Playwright (`frontend/playwright.config.ts`, `frontend/e2e/`)

- Только Chromium, `baseURL: http://localhost:3001`, в CI — 1 повтор.
- Отчёты (reporter): `list` — вывод в консоль, и `html` с `open: "never"` — отчёт в `playwright-report/`.
  Без `html` папка отчёта не создаётся (по умолчанию reporter — `list`, в CI — `dot`), и в CI нечего выгружать
  артефактом. Без `open: "never"` при падении теста локально отчёт открывается сам, и команда ждёт Ctrl+C.
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
  или переименования страниц. Порядок (по исходнику Playwright): `webServer` запускается до `globalSetup`,
  а `globalTeardown` выполняется до остановки серверов — `.next-e2e` удаляется, пока `next start` ещё работает.
  На Linux это не мешает, а статичная страница ничего туда не пишет. Если после прогона папка `.next-e2e`
  снова появилась — причина в этом.
- Нужна только запущенная БД. Если запущен dev-сервер на 3000, e2e ему не мешает
  (`.next/dev` и `.next-e2e` — разные папки). После e2e `git status` чист, папки `.next-e2e` нет.
- Браузер ставится один раз: `npx playwright install chromium` в `frontend/`; на Linux/WSL ещё системные
  библиотеки — `sudo npx playwright install-deps chromium` (шаг в README).

## 7. scripts/check.sh

1. Bash; корень проекта вычисляется от расположения скрипта — запускается из любой папки.
2. Скрипт не меняет рабочие файлы проекта. Временные файлы — в папке, созданной `mktemp -d` внутри `.tmp/`
   в корне проекта (`.tmp/` создаётся при необходимости и добавлена в корневой `.gitignore`). Папка удаляется
   через `trap` на `EXIT` — при любом завершении скрипта, в том числе при ошибке и Ctrl+C.
3. Предусловия (при невыполнении — подсказка и выход с кодом 1, проверки не запускаются):
   - БД доступна: короткий Python-код через `uv run` подключается к `TEST_DATABASE_URL` из настроек бэкенда
     (учитывает `backend/.env`). Подсказка: «запусти `docker compose up -d --wait` в корне проекта»;
   - есть `frontend/node_modules`, иначе подсказка «выполни `npm ci` в папке frontend/».
4. Проверки — все по очереди, падение одной не останавливает остальные:
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
   10. типы API свежие: те же два шага, что в `gen:api` (выгрузка OpenAPI через `export_openapi`, затем
       локальный `openapi-typescript` из `frontend/node_modules`), но с файлами во временной папке; затем
       побайтовое сравнение с `frontend/openapi.json` и `frontend/src/lib/api/schema.d.ts`. Расхождение
       или отсутствие файла → FAIL и подсказка «выполни `npm run gen:api` в папке frontend/». Сравниваются
       файлы, а не `git diff`: свежие типы, ещё не добавленные через `git add`, не дают ложного FAIL.
       Команды генерации в `check.sh` и в `gen:api` должны совпадать — меняя одно, менять и другое.
5. Сводка: каждая проверка — OK или FAIL; код выхода 1, если упала хоть одна. e2e в скрипт не входит.
6. Проверка опытом (этап 3):
   - на свежих файлах проверка 10 — OK;
   - после изменения эндпоинта или схемы в бэкенде без `gen:api` — FAIL с подсказкой; затем код бэкенда
     вернуть как было — снова OK;
   - после успешного прогона, после прогона с FAIL и после прерывания (Ctrl+C) в `.tmp/` не остаётся папок.

## 8. CI (`.github/workflows/ci.yml`)

- Запуск: `pull_request` и `push` в `main`. `permissions: contents: read`.
  `concurrency` — новый прогон той же ветки отменяет старый.
- Зависимости строго по lock-файлам: `uv sync --locked`, `npm ci`.
- `setup-node`: `node-version-file: frontend/.nvmrc`, `cache: npm`, `cache-dependency-path: frontend/package-lock.json`.
  Lock-файл лежит не в корне: без `cache-dependency-path` `setup-node` падает («Dependencies lock file is not found»).
- Версии actions (`checkout`, `setup-node`, `astral-sh/setup-uv`, `upload-artifact`) — актуальные мажорные,
  сверяются при написании плана.

| Задание | Шаги |
|---|---|
| `backend` | сервис `postgres:18` (`POSTGRES_USER/PASSWORD=postgres`, `POSTGRES_DB=wms_crm_test` — тестовая БД создаётся настройками сервиса, healthcheck `pg_isready -h localhost -U postgres` — `-h` по той же причине, что в 3.1, порт 5432); checkout, setup-uv (Python из `.python-version`), `uv sync --locked`, `ruff check .`, `ruff format --check .`, `mypy app`, `pytest`, `alembic upgrade head` + `alembic check` с `USE_TEST_DATABASE=true` |
| `frontend` | setup-node (см. выше), `npm ci`, lint, format:check, typecheck, test; проверка свежести типов API: setup-uv, `uv sync --locked` в `backend/`, `npm run gen:api`, затем **из корня репозитория** (шаг без `working-directory: frontend`) `git diff --exit-code -- frontend/openapi.json frontend/src/lib/api/schema.d.ts`. Пути в `git diff` считаются от текущей папки: из `frontend/` они указывали бы на несуществующие файлы, и проверка проходила бы всегда |
| `e2e` | тот же сервис Postgres; setup-uv + `uv sync --locked`, setup-node (см. выше) + `npm ci`, `npx playwright install --with-deps chromium`, `npm run test:e2e`; при падении — `playwright-report` выгружается артефактом |

## 9. Документация

- **README.md** (по-русски): требования (Docker, uv, Node 24 через nvm); запуск с нуля по шагам, включая браузер
  для Playwright (`npx playwright install chromium`, на Linux/WSL ещё `sudo npx playwright install-deps chromium`);
  все команды (БД — `docker compose up -d --wait`); e2e (порты 8001/3001, не запускать одновременно с pytest);
  смена пароля БД; пересоздание БД (`docker compose down -v && docker compose up -d --wait` — init-скрипт
  срабатывает только на пустом томе); структура проекта.
- **Корневой CLAUDE.md** (правки):
  - команда БД — `docker compose up -d --wait` (вместо `docker compose up -d db`);
  - в строке про e2e: не запускать одновременно с pytest — обе используют `wms_crm_test`;
  - раздел «Библиотеки»: для Next.js — встроенная документация `frontend/node_modules/next/dist/docs/`
    (см. `frontend/AGENTS.md`), для остальных библиотек — Context7.
- **backend/CLAUDE.md** (коротко): команды; эндпоинты с БД — обычный `def`; адрес БД — только через
  `effective_database_url`; модели наследуют `Base` и реэкспортируются в `app/models/__init__.py`;
  миграции — `alembic revision --autogenerate`, автосгенерированную миграцию всегда просматривать
  (переименование колонки autogenerate видит как удаление и создание — исправлять вручную на `op.alter_column`);
  после изменения эндпоинтов или схем — `npm run gen:api` в `frontend/` и закоммитить `openapi.json` и `schema.d.ts`;
  тесты — через фикстуры `client` и `db_session`.
- **frontend/CLAUDE.md**: первая строка — `@AGENTS.md` (её создаёт `create-next-app`), ниже коротко: команды;
  тексты интерфейса — только в `messages/*.json` (ru и en); запросы — через `src/lib/api/client.ts`;
  после изменения API — `npm run gen:api`; компоненты — `npx shadcn add`; Vitest — только чистая логика
  (`src/lib`, `src/i18n`); e2e — в `e2e/`.
- **docs/ROADMAP.md**: только модули и статусы. Создаётся на этапе 4, скелет проекта — сразу «готово»;
  пользователи и роли, каталог товаров, склады, остатки и движения, переключение языка ru/en — «запланировано».

## 10. Этапы реализации

Порядок завершения каждого этапа:

1. В конце этапа — список команд, которыми владелец проверяет результат (с ожидаемым результатом каждой).
2. Владелец проверяет, затем коммит (после подтверждения).
3. После коммита — остановка до команды владельца на следующий этап.

Этапы:

1. **Бэкенд + БД:** `docker-compose.yml`, init-скрипт, корневой `.env.example`, весь `backend/`
   (включая выгрузку OpenAPI, Alembic и тесты).
2. **Фронтенд:** проект Next.js (с `AGENTS.md` и `CLAUDE.md` от `create-next-app`), next-intl, shadcn/ui (Base UI),
   API-клиент и `gen:api`, Vitest, Playwright. По TDD сначала падающие тесты — Vitest (`backend-status`,
   `messages`) и e2e (`home.spec.ts`), потом код: главная страница и `BackendStatus`. В конце — проверка
   типизации ключей переводов (5.3).
3. **Проверки:** `scripts/check.sh` (включая проверку свежести типов API), `.tmp/` в корневом `.gitignore`,
   проверка опытом из раздела 7.
4. **CI и документация:** `ci.yml`, README, правки корневого `CLAUDE.md`, `backend/CLAUDE.md`, `frontend/CLAUDE.md`,
   `docs/ROADMAP.md`. Затем финальное ревью ветки моделью **opus** (дифф меняет `.env.example` и пароли БД —
   правило CLAUDE.md), push и PR (после подтверждения) и зелёный CI.

## 11. Сверка с документацией

Сверено при ревью 2026-10-17 (Context7, исходники, опыты) и учтено выше:

- Next.js 16: `next dev` пишет в `.next/dev`, замок `<distDir>/lock` ставят `next dev` и `next build`;
  `next typegen` пишет в `<distDir>/types` и пересоздаёт `next-env.d.ts`; `next build` требует в `include`
  `<distDir>/types/**/*.ts` и `<distDir>/dev/types/**/*.ts`; `create-next-app` с 16.2 создаёт `AGENTS.md`
  и `CLAUDE.md` (отключается `--no-agents-md`).
- openapi-fetch: `baseUrl` необязателен; при сетевой ошибке запрос бросает исключение.
- next-intl: без i18n-маршрутизации — `getRequestConfig` в `src/i18n/request.ts`, `NextIntlClientProvider`
  в layout; типизация — `AppConfig` в `global.ts`.
- Playwright: `webServer` массивом; команда идёт через shell (`&&` работает); `env` дополняет `process.env`;
  `globalTeardown` — до остановки `webServer`; reporter по умолчанию `list`/`dot`, `html` по умолчанию
  открывается при падении.
- SQLAlchemy 2.0: `join_transaction_mode="create_savepoint"` — рецепт документации для тестов;
  pydantic-settings: `extra="forbid"` по умолчанию действует и на `.env`.
- Alembic: `config.attributes`, `alembic check`; несколько `post_write_hooks` выполняются по порядку;
  тип хука `module` — с 1.16.3; стандартный `script.py.mako` не проходит `ruff check` без `--fix`.
- Docker: `postgres:18` — том `/var/lib/postgresql`; временный сервер init слушает только сокет;
  `up --wait` ждёт `healthy` и падает при `unhealthy`; неудачи в `start_period` не считаются.
- uv 0.13: `uv init` создаёт пакет с `src/`; `uv init --bare` — только `pyproject.toml`; без `pythonpath`
  pytest не видит `app`.
- GitHub Actions: `setup-node` с `cache: npm` без `cache-dependency-path` ищет lock-файл в корне;
  `setup-uv`: входы `python-version`, `working-directory`, `enable-cache`.
- git: `check-ignore` без `--no-index` молчит для закоммиченных файлов; пути в `git diff` — от текущей папки.

Сверить при написании плана:

- флаги `create-next-app` для запуска без вопросов (React Compiler, Turbopack) и полный состав файлов;
- `shadcn init --base base`: стиль (пресет) и устанавливаемые зависимости;
- синтаксис хуков `module` и `file_template` в `alembic.ini`;
- актуальные мажорные версии actions (`checkout`, `setup-node`, `astral-sh/setup-uv`, `upload-artifact`).

Источник — Context7; для Next.js после создания проекта — встроенная документация `frontend/node_modules/next/dist/docs/`.
