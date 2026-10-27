#!/usr/bin/env bash
# Runs all project checks one by one and prints a summary.
# Works from any directory. Exit code: 0 if every check passed, 1 otherwise
# (130 or 143 if interrupted by SIGINT or SIGTERM).

# No -e: a failing check must not stop the remaining ones.
set -uo pipefail

# cd prints the directory when CDPATH is used, so its output is discarded.
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"

# Temporary files live in .tmp/ (git-ignored) and are removed on any exit, including Ctrl+C.
mkdir -p "$ROOT/.tmp" || { echo 'Не удалось создать папку .tmp/ в корне проекта' >&2; exit 1; }
TMP_DIR="$(mktemp -d "$ROOT/.tmp/check.XXXXXX")" ||
  { echo 'Не удалось создать временную папку в .tmp/' >&2; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT
# Explicit exits on signals guarantee that the EXIT trap runs.
trap 'exit 130' INT
trap 'exit 143' TERM

DB_CHECK='
from sqlalchemy import create_engine, text

from app.core.config import get_settings

engine = create_engine(get_settings().test_database_url, connect_args={"connect_timeout": 3})
with engine.connect() as connection:
    connection.execute(text("SELECT 1"))
'

DB_CHECK_LOG="$TMP_DIR/db-check.log"
if ! (cd "$ROOT/backend" && uv run python -c "$DB_CHECK") >"$DB_CHECK_LOG" 2>&1; then
  # shellcheck disable=SC2016  # backticks in messages are literal text
  echo 'БД недоступна: запусти `docker compose up -d --wait` в корне проекта' >&2
  echo 'Подробности:' >&2
  # The real cause may be a wrong password, a missing database or uv; passwords are masked.
  tail -n 5 "$DB_CHECK_LOG" |
    sed -E -e 's#(://[^:/@]*:)[^@]*@#\1***@#g' -e 's#(password=)[^ ]*#\1***#g' >&2
  exit 1
fi

if [[ ! -d "$ROOT/frontend/node_modules" ]]; then
  # shellcheck disable=SC2016  # backticks in messages are literal text
  echo 'Нет frontend/node_modules: выполни `npm ci` в папке frontend/' >&2
  exit 1
fi

RESULTS=()
FAILED=0

# run_check <name> <dir> <command...>: runs the command in <dir> and records OK or FAIL.
run_check() {
  local name="$1" dir="$2"
  shift 2
  echo "==> $name"
  if (cd "$dir" && "$@"); then
    RESULTS+=("OK    $name")
  else
    RESULTS+=("FAIL  $name")
    FAILED=1
  fi
  echo
}

# Keep in sync with the "gen:api" script in frontend/package.json: the same two generation
# steps, but the output goes to $TMP_DIR and is compared with the committed files.
# Runs in frontend/.
# shellcheck disable=SC2317  # invoked indirectly via run_check
check_api_types() {
  uv run --directory "$ROOT/backend" python -m app.export_openapi "$TMP_DIR/openapi.json" ||
    return 1
  ./node_modules/.bin/openapi-typescript "$TMP_DIR/openapi.json" -o "$TMP_DIR/schema.d.ts" ||
    return 1
  if ! cmp -s "$TMP_DIR/openapi.json" openapi.json ||
    ! cmp -s "$TMP_DIR/schema.d.ts" src/lib/api/schema.d.ts; then
    # shellcheck disable=SC2016  # backticks in messages are literal text
    echo 'Типы API устарели или отсутствуют: выполни `npm run gen:api` в папке frontend/' >&2
    return 1
  fi
}

run_check "ruff check ." "$ROOT/backend" uv run ruff check .
run_check "ruff format --check ." "$ROOT/backend" uv run ruff format --check .
run_check "mypy app" "$ROOT/backend" uv run mypy app
run_check "pytest" "$ROOT/backend" uv run pytest
run_check "alembic check" "$ROOT/backend" \
  env USE_TEST_DATABASE=true bash -c 'uv run alembic upgrade head && uv run alembic check'
run_check "npm run lint" "$ROOT/frontend" npm run lint
run_check "npm run format:check" "$ROOT/frontend" npm run format:check
run_check "npm run typecheck" "$ROOT/frontend" npm run typecheck
run_check "npm run test" "$ROOT/frontend" npm run test
run_check "типы API свежие" "$ROOT/frontend" check_api_types

echo "==> Итог"
printf '%s\n' "${RESULTS[@]}"
exit "$FAILED"
