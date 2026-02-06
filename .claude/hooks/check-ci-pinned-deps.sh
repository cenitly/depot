#!/usr/bin/env bash
# Lint CI workflow files: check for unpinned actions and run actionlint.
set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check workflow files.
case "$FILE_PATH" in
  */.forgejo/workflows/*.yaml|*/.forgejo/workflows/*.yml|*/.github/workflows/*.yaml|*/.github/workflows/*.yml) ;;
  *) exit 0 ;;
esac

ERRORS=""

# Check for unpinned action references not locked to a 40-char commit SHA.
UNPINNED=$(grep -nE '^\s*-?\s*uses:\s+' "$FILE_PATH" \
  | grep -vE '^\s*#' \
  | grep -vE '@[0-9a-f]{40}\b' || true)

if [ -n "$UNPINNED" ]; then
  ERRORS+="$FILE_PATH has unpinned action dependencies (not locked to a commit SHA):"$'\n'
  ERRORS+="$UNPINNED"$'\n'
  ERRORS+="Pin actions to full commit SHAs with a version comment, e.g.:"$'\n'
  ERRORS+="  uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4"$'\n'
fi

# Run actionlint.
LINT_OUTPUT=$(actionlint "$FILE_PATH" 2>&1) || true
if [ -n "$LINT_OUTPUT" ]; then
  ERRORS+="actionlint errors in $FILE_PATH:"$'\n'
  ERRORS+="$LINT_OUTPUT"$'\n'
fi

if [ -n "$ERRORS" ]; then
  echo "$ERRORS" >&2
  exit 2
fi

exit 0
