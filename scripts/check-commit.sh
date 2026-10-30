#!/bin/sh
# Cheap pre-commit checks. The full gate is `make check`.
set -eu

if ! git config --local user.email >/dev/null; then
  echo "check-commit: set a repo-local user.email, so a global identity can't reach this public repo" >&2
  exit 1
fi

added=$(git diff --cached --no-color -U0 --diff-filter=ACMR -- . ':(exclude)scripts/check-commit.sh' | grep '^+' | grep -v '^+++' || true)
if printf '%s\n' "$added" | grep -E '/Users/|gh[pousr]_[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY' >/dev/null; then
  echo "check-commit: staged text contains a machine path or a secret" >&2
  exit 1
fi

swift_files=$(git diff --cached --name-only --diff-filter=ACMR -- '*.swift')
if [ -n "$swift_files" ]; then
  # shellcheck disable=SC2086
  swift format lint --strict $swift_files
fi
