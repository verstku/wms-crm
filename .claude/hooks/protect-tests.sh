#!/usr/bin/env bash
# Asks the owner before Claude changes a test or a spec that already exists in main.
input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[[ -z "$file" ]] && exit 0
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
rel="${file#"$root"/}"

case "$rel" in
  backend/tests/*|frontend/e2e/*|*.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|docs/superpowers/specs/*) ;;
  *) exit 0 ;;
esac

if git -C "$root" cat-file -e "main:$rel" 2>/dev/null; then
  jq -n --arg f "$rel" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: ("Файл " + $f + " уже есть в main (тест или спека). Менять его можно только с разрешения владельца проекта.")}}'
fi
exit 0
