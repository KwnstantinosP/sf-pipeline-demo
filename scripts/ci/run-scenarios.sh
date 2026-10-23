#!/usr/bin/env bash
# Runs every tests/scenarios/*.apex file against the default org as anonymous Apex.
# A scenario passes when it finishes without an exception: each one checks its outcome with
# Assert and rolls back its own data, so the org is left as it was.
#
# Usage: run-scenarios.sh
set -euo pipefail

summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
passed=0
failed=0

shopt -s nullglob
files=(tests/scenarios/*.apex)

{
  echo "### Scenario tests"
  echo "| Scenario | Result |"
  echo "|---|---|"
} >> "$summary"

for file in "${files[@]}"; do
  name=$(basename "$file" .apex)
  description=$(sed -n 's#^// Scenario: ##p' "$file" | head -1)
  result=$(sf apex run --file "$file" --json 2>/dev/null || true)

  # Prints "pass" or "fail <reason>" from the sf apex run JSON.
  outcome=$(echo "$result" | node -e '
    let s = "";
    process.stdin.on("data", (d) => (s += d)).on("end", () => {
      let j;
      try { j = JSON.parse(s); } catch (e) { return console.log("fail Could not read the sf CLI output"); }
      const r = j.result || {};
      if (r.success) return console.log("pass");
      const reason = !r.compiled && r.compiled !== undefined
        ? `Does not compile: ${r.compileProblem} (line ${r.line})`
        : r.exceptionMessage || j.message || "Unknown failure";
      console.log("fail " + reason.replace(/\s+/g, " "));
    });')

  if [ "$outcome" = pass ]; then
    passed=$((passed + 1))
    echo "PASS  $name  $description"
    echo "| $name: $description | Passed |" >> "$summary"
  else
    failed=$((failed + 1))
    reason="${outcome#fail }"
    echo "FAIL  $name  $description"
    echo "::error title=Scenario failed: $name::$reason"
    echo "| $name: $description | **Failed**: $reason |" >> "$summary"
  fi
done

if [ ${#files[@]} -eq 0 ]; then
  echo "No scenarios found in tests/scenarios."
  echo "| (none) | |" >> "$summary"
fi

echo "$passed passed, $failed failed"
echo "**$passed passed, $failed failed**" >> "$summary"
[ "$failed" -eq 0 ]
