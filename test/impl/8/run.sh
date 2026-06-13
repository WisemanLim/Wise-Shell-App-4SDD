#!/usr/bin/env bash
# impl/8 — scan ALL registered repos, generate compose/Makefile in the ops repo.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

# shellcheck disable=SC1090
. "${ROOT}/wsa4sdd.sh"

PASS=0; FAIL=0
tpass() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

T="$(mktemp -d)"

echo "1-5 — apps spread across sibling repos, compose lands in ops repo"
WS="${T}/ws"; mkdir -p "${WS}/ops" "${WS}/svcA/apps/python-cli" "${WS}/svcB"
printf 'print(1)\n' > "${WS}/svcA/apps/python-cli/hello.py"
printf '{"scripts":{"start":"node index.js"}}\n' > "${WS}/svcB/package.json"; : > "${WS}/svcB/index.js"
WORKSPACE_DIR="${WS}"; OPS_DIR="${WS}/ops"; OPS_NAME="ops"; SYNCED_NAMES=(ops svcA svcB); AUTO_GENERATED=0
ensure_runnable_ops >/dev/null 2>&1; rc=$?
check "1a rc=0"                 '[[ "'"${rc}"'" -eq 0 ]]'
check "1b AUTO=1"               '[[ "${AUTO_GENERATED}" -eq 1 ]]'
check "1c 2 apps"               '[[ "${#RUN_APP_DIR[@]}" -eq 2 ]]'
check "2a compose in ops repo"  '[[ -f "${WS}/ops/docker-compose.yml" ]]'
check "2b svcA service"         'grep -q "svca-python-cli:" "${WS}/ops/docker-compose.yml"'
check "2c svcB service"         'grep -q "svcb:" "${WS}/ops/docker-compose.yml"'
check "3a ../svcA context"      'grep -q "build: ../svcA/apps/python-cli" "${WS}/ops/docker-compose.yml"'
check "3b ../svcB context"      'grep -q "build: ../svcB$" "${WS}/ops/docker-compose.yml"'
check "4a Dockerfile in svcA"   '[[ -f "${WS}/svcA/apps/python-cli/Dockerfile" ]]'
check "4b Dockerfile in svcB"   '[[ -f "${WS}/svcB/Dockerfile" ]]'
check "5 Makefile in ops"       '[[ -f "${WS}/ops/Makefile" ]] && make -C "${WS}/ops" -n up >/dev/null 2>&1'

echo "6 — ops repo apps keep short names; sibling repos prefixed"
WS2="${T}/ws2"; mkdir -p "${WS2}/ops/apps/api" "${WS2}/web"
printf 'print(1)\n' > "${WS2}/ops/apps/api/main.py"
printf '{}\n' > "${WS2}/web/package.json"; : > "${WS2}/web/server.js"
WORKSPACE_DIR="${WS2}"; OPS_DIR="${WS2}/ops"; OPS_NAME="ops"; SYNCED_NAMES=(ops web)
detect_run_apps
check "6a ops app short name 'api'" 'printf "%s\n" "${RUN_APP_NAME[@]}" | grep -qx "api"'
check "6b sibling prefixed 'web'"   'printf "%s\n" "${RUN_APP_NAME[@]}" | grep -qx "web"'
check "6c ops app ctx relative"     '[[ "$(_app_build_context "${WS2}/ops/apps/api")" == "apps/api" ]]'
check "6d sibling ctx ../web"       '[[ "$(_app_build_context "${WS2}/web")" == "../web" ]]'

echo "7 — fallback: no SYNCED_NAMES -> scan OPS_DIR only"
WS3="${T}/ws3"; mkdir -p "${WS3}/repo/apps/x"; printf 'print(1)\n' > "${WS3}/repo/apps/x/hello.py"
mkdir -p "${WS3}/other"; printf 'print(1)\n' > "${WS3}/other/hello.py"
WORKSPACE_DIR=""; OPS_DIR="${WS3}/repo"; OPS_NAME="repo"; SYNCED_NAMES=()
detect_run_apps
check "7 only ops scanned (1 app)" '[[ "${#RUN_APP_DIR[@]}" -eq 1 ]]'

rm -rf "${T}"
echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
