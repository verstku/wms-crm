# Бэкенд — правила

## Команды (из папки backend/)
- запуск:          uv run uvicorn app.main:app --reload --port 8000
- тесты:           uv run pytest
- линтеры и типы:  uv run ruff check . && uv run ruff format --check . && uv run mypy app
- миграции:        uv run alembic upgrade head
- новая миграция:  uv run alembic revision --autogenerate -m "add products table"
- пакеты:          uv add <пакет> (dev-зависимости — uv add --dev <пакет>)

## Код
- Эндпоинты, которые работают с БД, — обычный `def`, не `async def`: SQLAlchemy у нас синхронный.
- Адрес БД берётся только из `get_settings().effective_database_url` (его используют `engine` и `alembic/env.py`).
  Свой выбор адреса не писать.
- Доступ к БД в коде приложения — только через зависимость `get_db`. `SessionLocal` напрямую не использовать:
  во время pytest он смотрит на рабочую `wms_crm`, а не на `wms_crm_test`.

## Модели и миграции
- Модели наследуют `Base` из `app/models/base.py` и реэкспортируются в `app/models/__init__.py` — иначе их
  не увидит Alembic.
- Миграции создаются через `uv run alembic revision --autogenerate -m "add products table"`. Описание миграции —
  по-английски: оно попадает в имя файла. Автосгенерированную миграцию
  всегда просматривать: переименование колонки autogenerate видит как удаление и создание — исправлять вручную
  на `op.alter_column`.

## API и фронтенд
- После изменения эндпоинтов или схем — `npm run gen:api` в папке frontend/ и закоммитить `frontend/openapi.json`
  и `frontend/src/lib/api/schema.d.ts`. Иначе `./scripts/check.sh` и CI упадут на проверке свежести типов API.

## Тесты
- Тесты с БД — через фикстуры `client` (TestClient) и `db_session` из `tests/conftest.py`. Каждый тест работает
  в транзакции, которая откатывается: даже `session.commit()` ничего не сохраняет.
- Перед первым тестом с `caplog` добавить `disable_existing_loggers=False` в вызов `fileConfig` в `alembic/env.py`:
  фикстура применяет миграции внутри pytest, и без этого `fileConfig` отключает логгеры приложения.
