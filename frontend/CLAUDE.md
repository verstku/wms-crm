@AGENTS.md

# Фронтенд — правила

## Команды (из папки frontend/)

- запуск: `npm run dev` (http://localhost:3000; бэкенд на 8000 должен быть запущен)
- проверки: `npm run lint && npm run format:check && npm run typecheck`
- форматирование: `npm run format`
- unit-тесты: `npm run test` (Vitest)
- e2e-тесты: `npm run test:e2e` (Playwright; нужна запущенная БД; не запускать одновременно с pytest и `./scripts/check.sh`)
- типы API: `npm run gen:api`
- пакеты: `npm install <пакет>` (dev-зависимости — `npm install -D <пакет>`)

## Код

- Тексты интерфейса — только в `messages/ru.json` и `messages/en.json` (ключи в обоих файлах одинаковые),
  в коде — через next-intl. Строками в коде не писать.
- Запросы к бэкенду — только через клиент `src/lib/api/client.ts`.
- После изменения API бэкенда — `npm run gen:api` и закоммитить `openapi.json` и `src/lib/api/schema.d.ts`.
- Компоненты shadcn/ui — через `npx shadcn add <компонент>`, затем сразу `npm run format`: shadcn генерирует код
  не в стиле Prettier проекта, и без этого упадёт `format:check`.

## Тесты

- Vitest — только чистая логика без React и DOM (`src/lib`, `src/i18n`), файлы `*.test.ts` рядом с кодом.
- e2e-тесты (Playwright) — в `e2e/`: пользовательские сценарии и интерфейс.

## Типы Next.js

- После клонирования и после `npm run test:e2e` выполнить `npm run typecheck` (или `npm run dev`), чтобы
  редактор видел типы Next.js: сборка для e2e переписывает `next-env.d.ts`.
