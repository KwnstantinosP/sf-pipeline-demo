#!/usr/bin/env bash
# Checks only the files a PR changed, so nobody needs Node, npm or git hooks locally.
#   ESLint on LWC JavaScript: errors fail the check.
#   Prettier on everything it can format: report only, unless STRICT_FORMAT=true.
# Findings show up as annotations on the PR's "Files changed" tab.
#
# Usage: quality-check.sh <base-ref>
set -euo pipefail

BASE="$1"
STRICT_FORMAT="${STRICT_FORMAT:-false}"
failed=false

mapfile -t changed < <(git diff --name-only --diff-filter=ACMR "$BASE" HEAD)
mapfile -t format_files < <(printf '%s\n' "${changed[@]}" | grep -E '\.(cls|trigger|xml|js|html|css|json|md|ya?ml)$' | grep -v 'package-lock.json' || true)
mapfile -t lint_files < <(printf '%s\n' "${changed[@]}" | grep -E '/lwc/.*\.js$' || true)

summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
echo "### Code quality (changed files only)" >> "$summary"

# ESLint
lint_errors=0
lint_warnings=0
if [ ${#lint_files[@]} -gt 0 ]; then
  npx eslint --format json "${lint_files[@]}" > eslint-result.json || true
  read -r lint_errors lint_warnings < <(node -e '
    const path = require("path");
    let errors = 0, warnings = 0;
    for (const file of require(path.resolve("eslint-result.json"))) {
      for (const m of file.messages) {
        const level = m.severity === 2 ? "error" : "warning";
        m.severity === 2 ? errors++ : warnings++;
        console.error(`::${level} file=${path.relative(process.cwd(), file.filePath).split(path.sep).join("/")},line=${m.line || 1},col=${m.column || 1}::${m.message} (${m.ruleId || "eslint"})`);
      }
    }
    console.log(errors, warnings);')
  [ "$lint_errors" -gt 0 ] && failed=true
fi
echo "- ESLint: ${#lint_files[@]} LWC file(s) checked, $lint_errors error(s), $lint_warnings warning(s)" >> "$summary"

# Prettier
unformatted=()
if [ ${#format_files[@]} -gt 0 ]; then
  mapfile -t unformatted < <(npx prettier --list-different "${format_files[@]}" || true)
fi
level=warning
if [ "$STRICT_FORMAT" = true ]; then level=error; fi
for f in "${unformatted[@]}"; do
  [ -z "$f" ] && continue
  echo "::$level file=$f::Not formatted with Prettier. Fix with: npx prettier --write $f"
done
if [ "$STRICT_FORMAT" = true ] && [ ${#unformatted[@]} -gt 0 ]; then failed=true; fi
echo "- Prettier: ${#format_files[@]} file(s) checked, ${#unformatted[@]} not formatted ($([ "$STRICT_FORMAT" = true ] && echo blocking || echo report only))" >> "$summary"

if [ "$failed" = true ]; then
  echo "Code quality check failed, see the annotations above."
  exit 1
fi
echo "Code quality check passed: $lint_errors ESLint errors, ${#unformatted[@]} unformatted file(s)."
