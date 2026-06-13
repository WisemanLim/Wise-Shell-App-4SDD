#!/usr/bin/env bash
# impl/9 — role classification + compose wiring (frontend↔backend↔database, cli no ports).
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

echo "2 — _classify_role"
check "2a frontend by name"  '[[ "$(_classify_role node-frontend node "[\"node\",\"server.js\"]" "")" == frontend ]]'
check "2b backend by uvicorn" '[[ "$(_classify_role python-backend python "[\"uvicorn\",\"app.main:app\"]" 8000)" == backend ]]'
check "2c database by name"  '[[ "$(_classify_role database python "[\"python\",\"main.py\"]" "")" == database ]]'
check "2d cli by name"       '[[ "$(_classify_role node-cli node "[\"node\",\"hello.js\"]" "")" == cli ]]'
check "2e api->backend"      '[[ "$(_classify_role my-api node "[\"npm\",\"start\"]" "")" == backend ]]'

echo "1 — frontend wired to backend, backend 8000 (no offset)"
R="${T}/s"; mkdir -p "${R}/apps/node-frontend" "${R}/apps/python-backend/app"
printf '{}\n' > "${R}/apps/node-frontend/package.json"; : > "${R}/apps/node-frontend/server.js"
printf '[project]\nname=b\ndependencies=["fastapi","uvicorn"]\n' > "${R}/apps/python-backend/pyproject.toml"
printf 'from fastapi import FastAPI\napp=FastAPI()\n' > "${R}/apps/python-backend/app/main.py"
OPS_DIR="${R}"; OPS_NAME=s; ensure_runnable_ops >/dev/null 2>&1
C="${R}/docker-compose.yml"
check "1a frontend BACKEND_URL"  'grep -q "BACKEND_URL=http://python-backend:8000" "${C}"'
check "1b frontend depends_on"   'grep -A6 "node-frontend:" "${C}" | grep -q "python-backend"'
check "1c frontend port 3000"    'grep -q "\"3000:3000\"" "${C}"'
check "1d backend 8000:8000"     'grep -q "\"8000:8000\"" "${C}"'
check "1e no 8001 offset"        '! grep -q "8001" "${C}"'

echo "3 — frontend+api+database+cli wiring"
R2="${T}/m"; mkdir -p "${R2}/frontend" "${R2}/api/app" "${R2}/database" "${R2}/node-cli"
printf '{}\n' > "${R2}/frontend/package.json"; : > "${R2}/frontend/server.js"
printf '[project]\nname=api\ndependencies=["fastapi","uvicorn"]\n' > "${R2}/api/pyproject.toml"
printf 'from fastapi import FastAPI\napp=FastAPI()\n' > "${R2}/api/app/main.py"
printf '[project]\nname=database\n' > "${R2}/database/pyproject.toml"; printf 'print(1)\n' > "${R2}/database/main.py"
printf '{"scripts":{"start":"node hello.js"}}\n' > "${R2}/node-cli/package.json"; : > "${R2}/node-cli/hello.js"
OPS_DIR="${R2}"; OPS_NAME=m; ensure_runnable_ops >/dev/null 2>&1
C2="${R2}/docker-compose.yml"
check "3a frontend->api"      'grep -q "BACKEND_URL=http://api:8000" "${C2}"'
check "3b api->database URL"  'grep -q "DATABASE_URL=postgresql://app:app@database:5432/app" "${C2}"'
check "3c database port 5432" 'grep -q "\"5432:5432\"" "${C2}"'
check "3d cli no ports"       '! ( grep -A4 "node-cli:" "${C2}" | grep -q "ports:" )'

echo "4 — cli classification (no ports)"
OPS_DIR="${R2}"; detect_run_apps
_role_of() { local n="$1" i; for ((i=0;i<${#RUN_APP_NAME[@]};i++)); do [[ "${RUN_APP_NAME[$i]}" == "$n" ]] && { echo "${RUN_APP_ROLE[$i]}"; return; }; done; }
check "4 node-cli role cli"   '[[ "$(_role_of node-cli)" == cli ]]'

echo "5 — multiple backends: host ports 8000 then 8001"
R3="${T}/b"; mkdir -p "${R3}/api-one/app" "${R3}/api-two/app"
for s in api-one api-two; do
  printf '[project]\nname=%s\ndependencies=["fastapi","uvicorn"]\n' "$s" > "${R3}/${s}/pyproject.toml"
  printf 'from fastapi import FastAPI\napp=FastAPI()\n' > "${R3}/${s}/app/main.py"
done
OPS_DIR="${R3}"; OPS_NAME=b; ensure_runnable_ops >/dev/null 2>&1
check "5a 8000 published"  'grep -q "\"8000:8000\"" "${R3}/docker-compose.yml"'
check "5b 8001 published"  'grep -q "\"8001:8000\"" "${R3}/docker-compose.yml"'

echo "6 — backend without database: no DATABASE_URL"
R4="${T}/n"; mkdir -p "${R4}/api/app"
printf '[project]\nname=api\ndependencies=["fastapi","uvicorn"]\n' > "${R4}/api/pyproject.toml"
printf 'from fastapi import FastAPI\napp=FastAPI()\n' > "${R4}/api/app/main.py"
OPS_DIR="${R4}"; OPS_NAME=n; ensure_runnable_ops >/dev/null 2>&1
check "6 no DATABASE_URL"  '! grep -q "DATABASE_URL" "${R4}/docker-compose.yml"'

rm -rf "${T}"
echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
