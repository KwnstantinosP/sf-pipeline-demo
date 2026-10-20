#!/usr/bin/env bash
# Builds the delta package between two git refs and decides which Apex tests to run.
#
# Usage: build-delta.sh <from-ref> <to-ref> <test-policy>
#   from-ref     last deployed commit; empty means nothing has been deployed yet, so all of force-app is packaged
#   test-policy  specified -> run the test classes matching the changed classes (RunLocalTests if any match is missing)
#                local     -> RunLocalTests whenever the delta contains Apex
#
# Writes delta/package/package.xml and delta/destructiveChanges/destructiveChanges.xml,
# and sets has_changes, test_level and tests on $GITHUB_OUTPUT.
set -euo pipefail

FROM="${1:-}"
TO="${2:-HEAD}"
POLICY="${3:-specified}"
OUT=delta
PKG="$OUT/package/package.xml"
DESTRUCTIVE="$OUT/destructiveChanges/destructiveChanges.xml"

rm -rf "$OUT"
mkdir -p "$OUT/package" "$OUT/destructiveChanges"

if [ -z "$FROM" ]; then
  echo "No previous deployment recorded, packaging all of force-app."
  sf project generate manifest --source-dir force-app --output-dir "$OUT/package" --type package
  POLICY=local
else
  echo "Building delta $FROM -> $TO"
  sf sgd source delta --from "$FROM" --to "$TO" --output-dir "$OUT" --source-dir force-app
fi

has_changes=false
grep -q "<types>" "$PKG" && has_changes=true
[ -f "$DESTRUCTIVE" ] && grep -q "<types>" "$DESTRUCTIVE" && has_changes=true

test_level=NoTestRun
tests=""
if grep -qE "<name>(ApexClass|ApexTrigger)</name>" "$PKG"; then
  test_level=RunLocalTests

  if [ "$POLICY" = specified ]; then
    found=()
    missing=()
    while read -r file; do
      [ -z "$file" ] && continue
      name=$(basename "$file")
      name="${name%.*}"
      if [[ "$file" == *.trigger ]]; then
        missing+=("$name")
      elif grep -qi "@istest" "$file"; then
        found+=("$name")
      else
        match=""
        for candidate in "${name}Test" "${name}_Test" "${name}TestClass"; do
          if [ -n "$(find force-app -name "${candidate}.cls" -print -quit)" ]; then
            match="$candidate"
            break
          fi
        done
        if [ -n "$match" ]; then found+=("$match"); else missing+=("$name"); fi
      fi
    done < <(git diff --name-only --diff-filter=AMR "$FROM" "$TO" -- force-app | grep -E '\.(cls|trigger)$' || true)

    if [ ${#missing[@]} -eq 0 ] && [ ${#found[@]} -gt 0 ]; then
      test_level=RunSpecifiedTests
      tests=$(printf '%s\n' "${found[@]}" | sort -u | tr '\n' ' ')
    elif [ ${#missing[@]} -gt 0 ]; then
      echo "No matching test class for: ${missing[*]}, falling back to RunLocalTests."
    fi
  fi
fi

echo "has_changes=$has_changes, test_level=$test_level, tests=$tests"
{
  echo "has_changes=$has_changes"
  echo "test_level=$test_level"
  echo "tests=$tests"
} >> "${GITHUB_OUTPUT:-/dev/null}"

{
  echo "### Delta package"
  echo "Test level: \`$test_level\` $tests"
  echo '```xml'
  cat "$PKG"
  echo '```'
  if [ -f "$DESTRUCTIVE" ] && grep -q "<types>" "$DESTRUCTIVE"; then
    echo "### Destructive changes"
    echo '```xml'
    cat "$DESTRUCTIVE"
    echo '```'
  fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
