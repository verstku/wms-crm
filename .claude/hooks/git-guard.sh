#!/usr/bin/env bash
# Blocks risky git operations made by Claude:
# commits and pushes to main, and any force push.
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
branch=$(git -C "$root" branch --show-current 2>/dev/null)

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

if [[ "$cmd" == *"git commit"* && "$branch" == "main" ]]; then
  deny "Коммиты в main запрещены. Сначала создай ветку от main (feature/..., fix/..., chore/...)."
fi

if [[ "$cmd" == *"git push"* ]]; then
  if [[ "$cmd" == *"--force"* || "$cmd" =~ [[:space:]]-f([[:space:]]|$) ]]; then
    deny "Force push запрещён."
  fi
  if [[ "$branch" == "main" || "$cmd" =~ [[:space:]:]main([[:space:]]|$) ]]; then
    deny "Push в main запрещён. Изменения попадают в main только через Pull Request."
  fi
fi
exit 0
