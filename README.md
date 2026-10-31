# Система управления складом (Warehouse Management System)

Веб-приложение складского учёта: товары, остатки, движения, несколько складов.

Сейчас в проекте только скелет: бэкенд с эндпоинтом `GET /api/health`, фронтенд со статусом бэкенда,
БД в Docker, проверки, e2e-тесты и CI. Планы — в [docs/ROADMAP.md](docs/ROADMAP.md).

## Требования

- [Docker](https://docs.docker.com/get-docker/) с Docker Compose — для PostgreSQL.
- [uv](https://docs.astral.sh/uv/) — Python и пакеты бэкенда (Python 3.13 uv скачает сам).
- Node.js 24 через [nvm](https://github.com/nvm-sh/nvm) — версия записана в `frontend/.nvmrc`; npm идёт вместе с Node.

## Первый запуск

Файлы `.env` для запуска не нужны: без них всё работает на значениях по умолчанию (пользователь и пароль БД —
`postgres`). Как поменять пароль — в разделе «Смена пароля БД».

1. Клонировать репозиторий:

   ```bash
   git clone https://github.com/verstku/wms-crm.git
   cd wms-crm
   ```

2. Запустить БД (из корня проекта). Команда ждёт, пока БД будет готова:

   ```bash
   docker compose up -d --wait
   ```

3. Установить зависимости бэкенда (из папки `backend/`):

   ```bash
   uv sync --locked
   ```

4. Установить Node.js и зависимости фронтенда (из папки `frontend/`):

   ```bash
   nvm install
   npm ci
   ```

   nvm включает Node только в текущем терминале. Если в новом терминале активна другая версия Node
   (`node -v` показывает не 24), выполните в папке `frontend/` команду `nvm use`: она берёт версию из `.nvmrc`.

5. Установить браузер для e2e-тестов (из папки `frontend/`):

   ```bash
   npx playwright install chromium
   ```

   На Linux и WSL нужны ещё системные библиотеки для браузера:

   ```bash
   sudo env "PATH=$PATH" npx playwright install-deps chromium
   ```

   Почему не просто `sudo npx ...`: Node стоит через nvm, а `sudo` сбрасывает `PATH` и не находит `npx`
   (`sudo: npx: command not found`). `env "PATH=$PATH"` передаёт команде ваш `PATH`.

6. Сгенерировать типы Next.js (из папки `frontend/`), чтобы редактор их видел:

   ```bash
   npm run typecheck
   ```

7. Проверить, что всё работает (из корня проекта):

   ```bash
   ./scripts/check.sh
   ```

   Сам скрипт работает из любой папки проекта, например из `backend/` — `../scripts/check.sh`.

Запуск приложения — два терминала:

```bash
# терминал 1, папка backend/
uv run uvicorn app.main:app --reload --port 8000

# терминал 2, папка frontend/
npm run dev
```

Откройте http://localhost:3000: заголовок «Система управления складом» и метка «Бэкенд: работает».
Документация API бэкенда — http://localhost:8000/docs.

## Команды

БД, из корня проекта:

| Что | Команда |
|---|---|
| запустить БД | `docker compose up -d --wait` |
| состояние БД | `docker compose ps` |
| остановить БД (данные сохранятся) | `docker compose stop` |

Бэкенд, из папки `backend/`:

| Что | Команда |
|---|---|
| запуск (http://localhost:8000) | `uv run uvicorn app.main:app --reload --port 8000` |
| тесты | `uv run pytest` |
| линтеры и типы | `uv run ruff check . && uv run ruff format --check . && uv run mypy app` |
| применить миграции | `uv run alembic upgrade head` |
| новая миграция | `uv run alembic revision --autogenerate -m "add products table"` |

Фронтенд, из папки `frontend/`:

| Что | Команда |
|---|---|
| запуск (http://localhost:3000) | `npm run dev` |
| линтер, форматирование, типы | `npm run lint && npm run format:check && npm run typecheck` |
| исправить форматирование | `npm run format` |
| unit-тесты (Vitest) | `npm run test` |
| e2e-тесты (Playwright) | `npm run test:e2e` |
| обновить типы API | `npm run gen:api` |

`npm run gen:api` берёт схему API прямо из кода бэкенда — запускать бэкенд не нужно. После изменения эндпоинтов
или схем бэкенда выполните её и закоммитьте `frontend/openapi.json` и `frontend/src/lib/api/schema.d.ts`.

Все проверки разом (линтеры, типы, тесты бэкенда и фронтенда, свежесть типов API; без e2e) — из корня проекта:

```bash
./scripts/check.sh
```

Сам скрипт работает из любой папки проекта, например из `backend/` — `../scripts/check.sh`.
Скрипту нужна запущенная БД. В конце он печатает сводку: каждая проверка — `OK` или `FAIL`.

## E2E-тесты

```bash
# папка frontend/, БД запущена
npm run test:e2e
```

- Playwright сам собирает фронтенд и запускает бэкенд на отдельных портах: бэкенд — 8001, фронтенд — 3001.
  Запущенные для разработки серверы (8000 и 3000) не мешают.
- Тесты используют базу `wms_crm_test` — ту же, что `uv run pytest`. Поэтому e2e-тесты нельзя запускать
  одновременно с `uv run pytest` или `./scripts/check.sh`.
- Если тест упал, отчёт лежит в `frontend/playwright-report/`; открыть его — `npx playwright show-report`.
- После e2e-тестов выполните `npm run typecheck` (или `npm run dev`): сборка для тестов переписывает
  `next-env.d.ts`, и без этого редактор не видит типы Next.js.

## Смена пароля БД

1. Скопировать примеры настроек, если файлов `.env` ещё нет (из корня проекта):

   ```bash
   cp .env.example .env
   cp backend/.env.example backend/.env
   ```

2. Поменять пароль в трёх местах: `POSTGRES_PASSWORD` в корневом `.env` и оба адреса БД (`DATABASE_URL`
   и `TEST_DATABASE_URL`) в `backend/.env`.

   В корневом `.env` пароль пишется как есть. В адресах БД в `backend/.env` спецсимволы пароля нужно
   кодировать (например, `@` → `%40`, `#` → `%23`), иначе адрес разберётся неверно и бэкенд не подключится
   к БД. Закодированный пароль печатает команда (из папки `backend/`, вместо `p@ss#1` — свой пароль):

   ```bash
   uv run python -c "from urllib.parse import quote; print(quote('p@ss#1', safe=''))"   # p%40ss%231
   ```

   Пробелы и `$` в пароле лучше не использовать: в корневом `.env` docker compose считает `#` после пробела
   началом комментария, а `$` — подстановкой переменной.

3. Пересоздать БД — см. следующий раздел. Пароль задаётся только при создании БД.

## Пересоздание БД

```bash
# из корня проекта
docker compose down -v && docker compose up -d --wait
```

`down -v` удаляет том с данными — **все данные БД пропадут**. Базы `wms_crm` и `wms_crm_test` создаёт
init-скрипт `docker/postgres/init/01-create-databases.sql`, а он срабатывает только на пустом томе. Поэтому
пересоздание нужно, если баз нет или если поменялся пароль.

## Структура проекта

```
wms-crm/
├── backend/                Python 3.13, FastAPI, SQLAlchemy, Alembic, pytest
│   ├── app/                код: api/ (эндпоинты), core/ (настройки, БД), models/, schemas/, services/
│   ├── alembic/            миграции БД
│   └── tests/              тесты pytest
├── frontend/               Next.js, TypeScript, Tailwind CSS, shadcn/ui
│   ├── messages/           тексты интерфейса: ru.json, en.json
│   ├── e2e/                e2e-тесты Playwright
│   ├── openapi.json        схема API (генерируется)
│   └── src/
│       ├── app/            страницы (App Router)
│       ├── components/     компоненты, ui/ — компоненты shadcn/ui
│       ├── i18n/           настройка переводов (next-intl)
│       └── lib/            логика; api/ — клиент API и типы (генерируются)
├── docker/postgres/init/   SQL-скрипт создания баз
├── scripts/check.sh        все проверки разом
├── .github/workflows/      CI (GitHub Actions)
├── docs/                   ROADMAP, спеки и планы
└── docker-compose.yml      PostgreSQL для разработки
```
