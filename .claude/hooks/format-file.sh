#!/usr/bin/env bash
# Formats the file Claude just edited. Never blocks Claude.
input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[[ -z "$file" || ! -f "$file" ]] && exit 0
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"

case "$file" in
  "$root"/backend/*.py)
    if [[ -x "$root/backend/.venv/bin/ruff" ]]; then
      "$root/backend/.venv/bin/ruff" format --quiet "$file" >/dev/null 2>&1
    fi
    ;;
  "$root"/frontend/*.ts|"$root"/frontend/*.tsx|"$root"/frontend/*.js|"$root"/frontend/*.mjs|"$root"/frontend/*.css|"$root"/frontend/*.json|"$root"/frontend/*.md)
    if [[ -x "$root/frontend/node_modules/.bin/prettier" ]]; then
      (cd "$root/frontend" && ./node_modules/.bin/prettier --write --log-level silent "$file") >/dev/null 2>&1
    fi
    ;;
esac
exit 0
