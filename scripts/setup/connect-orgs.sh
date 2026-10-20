#!/usr/bin/env bash
# Logs in to the four demo orgs, then copies each auth URL to the clipboard, one at a time,
# for pasting into the GitHub environment secrets. The URLs are never printed.
#
# Usage (Git Bash, from the repo root): ./scripts/setup/connect-orgs.sh
# Needs: sf CLI, node. Create the GitHub environments first (README setup step 4).
set -euo pipefail

declare -A ORG_IDS=()

json_field() {
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=process.argv[1].split(".").reduce((o,k)=>o&&o[k],JSON.parse(s));process.stdout.write(String(v??""))})' "$1"
}

login() {
  local alias=$1
  echo
  echo "=== $alias ==="
  echo "Log in with the $alias org's username. If the browser is already signed in to another"
  echo "demo org, log out first (or use a private window), otherwise the wrong org gets linked."
  read -rp "Press Enter to open the browser..."
  sf org login web --alias "$alias" --instance-url https://login.salesforce.com

  # sf can exit non-zero on Windows even when it succeeds, so check the output instead.
  local info org_id username
  info=$(sf org display --target-org "$alias" --json 2>/dev/null || true)
  org_id=$(echo "$info" | json_field result.id)
  username=$(echo "$info" | json_field result.username)
  [ -n "$org_id" ] || { echo "ERROR: could not read org details for $alias"; exit 1; }
  echo "Linked $alias -> $username ($org_id)"

  for other in "${!ORG_IDS[@]}"; do
    if [ "${ORG_IDS[$other]}" = "$org_id" ]; then
      echo "ERROR: $alias is the same org as $other. Log out in the browser and run the script again."
      exit 1
    fi
  done
  ORG_IDS[$alias]=$org_id
}

copy_secret() {
  local alias=$1 env=$2 url
  url=$( (sf org display --target-org "$alias" --verbose --json 2>/dev/null || true) | json_field result.sfdxAuthUrl)
  [ -n "$url" ] || { echo "ERROR: no auth URL for $alias"; exit 1; }
  printf '%s' "$url" | clip.exe
  echo
  echo "Copied the $alias auth URL to the clipboard."
  echo "GitHub: Settings -> Environments -> $env -> Add environment secret"
  echo "  Name: SFDX_AUTH_URL    Value: paste (Ctrl+V)"
  read -rp "Press Enter once it is saved..."
}

if [ "${1:-}" != "--skip-login" ]; then
  login demo-dev
  login demo-sit
  login demo-uat
  login demo-prod
fi

copy_secret demo-dev DEV
copy_secret demo-sit SIT
copy_secret demo-uat UAT
copy_secret demo-prod PRODUCTION-VALIDATE
copy_secret demo-prod PRODUCTION

printf '' | clip.exe
echo
echo "Done, clipboard cleared."
