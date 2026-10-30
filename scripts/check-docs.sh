#!/bin/sh
# Delivery docs stay small. See ORCHESTRATOR.md, "Process budget".
set -eu

status=0
check() {
  lines=$(wc -l < "$1" | tr -d ' ')
  if [ "$lines" -gt "$2" ]; then
    echo "check-docs: $1 has $lines lines, limit $2" >&2
    status=1
  fi
}

check ORCHESTRATOR.md 100
check HANDOFF.md 40
check AGENTS.md 40
exit "$status"
