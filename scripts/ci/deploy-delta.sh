#!/usr/bin/env bash
# Deploys the package built by build-delta.sh to the default org.
#
# Usage: deploy-delta.sh <mode> <test-level> [tests]
#   check    -> check-only deploy, nothing is saved in the org
#   validate -> check-only deploy that can be quick-deployed later; sets job_id on $GITHUB_OUTPUT
#   deploy   -> real deploy
set -euo pipefail

MODE="$1"
TEST_LEVEL="$2"
TESTS="${3:-}"
DESTRUCTIVE=delta/destructiveChanges/destructiveChanges.xml

args=(--manifest delta/package/package.xml --test-level "$TEST_LEVEL" --wait 120)
if [ -f "$DESTRUCTIVE" ] && grep -q "<types>" "$DESTRUCTIVE"; then
  args+=(--post-destructive-changes "$DESTRUCTIVE")
fi
for t in $TESTS; do
  args+=(--tests "$t")
done

# Quick deploy needs a run with tests, so a delta without Apex gets a plain check instead.
if [ "$MODE" = validate ] && [ "$TEST_LEVEL" = NoTestRun ]; then
  echo "No Apex in the delta, running a plain check-only deploy."
  MODE=check
fi

case "$MODE" in
  check)
    sf project deploy start --dry-run "${args[@]}"
    ;;
  deploy)
    sf project deploy start "${args[@]}"
    ;;
  validate)
    if ! sf project deploy validate "${args[@]}" --json > validate-result.json; then
      jq '.message, .result.details.componentFailures, .result.details.runTestResult.failures' validate-result.json || cat validate-result.json
      exit 1
    fi
    job_id=$(jq -r '.result.id' validate-result.json)
    echo "Validation $job_id passed and can be quick-deployed."
    echo "job_id=$job_id" >> "${GITHUB_OUTPUT:-/dev/null}"
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
