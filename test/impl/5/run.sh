#!/usr/bin/env bash
# impl/5 — ensure_runnable_ops: auto-generate compose/Makefile or refuse. No network.
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

echo "1 — python project (hello.py) auto-generates"
mkdir -p "${T}/py"; printf 'print("hi")\n' > "${T}/py/hello.py"
OPS_DIR="${T}/py"; OPS_NAME="py"; AUTO_GENERATED=0
ensure_runnable_ops >/dev/null 2>&1; rc=$?
check "1a rc=0"            '[[ "'"${rc}"'" -eq 0 ]]'
check "1b AUTO_GENERATED"  '[[ "${AUTO_GENERATED}" -eq 1 ]]'
check "1c kind=python"     '[[ "${RUN_APP_KIND[0]}" == python ]]'
check "1d Dockerfile"      '[[ -f "${T}/py/Dockerfile" ]]'
check "1e compose"         '[[ -f "${T}/py/docker-compose.yml" ]]'
check "1f Makefile"        '[[ -f "${T}/py/Makefile" ]]'
check "1g CMD python entry" 'grep -q "python.*hello.py" "${T}/py/Dockerfile"'

echo "2 — node project (package.json start)"
mkdir -p "${T}/nd"; printf '{"scripts":{"start":"node index.js"}}\n' > "${T}/nd/package.json"; : > "${T}/nd/index.js"
OPS_DIR="${T}/nd"; OPS_NAME="nd"; AUTO_GENERATED=0
ensure_runnable_ops >/dev/null 2>&1; rc=$?
check "2a rc=0"            '[[ "'"${rc}"'" -eq 0 ]]'
check "2b AUTO_GENERATED"  '[[ "${AUTO_GENERATED}" -eq 1 ]]'
check "2c kind=node"       '[[ "${RUN_APP_KIND[0]}" == node ]]'
check "2d CMD npm start"   'grep -q "npm.*start" "${T}/nd/Dockerfile"'

echo "3 — empty repo -> cannot run"
mkdir -p "${T}/empty"; echo "# r" > "${T}/empty/README.md"
OPS_DIR="${T}/empty"; OPS_NAME="empty"
out3="$(ensure_runnable_ops 2>&1)"; rc=$?
check "3a rc!=0"           '[[ "'"${rc}"'" -ne 0 ]]'
check "3b cannot-run msg"  'grep -q "Cannot prepare a deployment" <<< "${out3}"'

echo "4 — compose present, no Makefile -> Makefile only (no Dockerfile)"
mkdir -p "${T}/comp"; printf 'services: {web: {image: nginx}}\n' > "${T}/comp/docker-compose.yml"
OPS_DIR="${T}/comp"; OPS_NAME="comp"; AUTO_GENERATED=0
ensure_runnable_ops >/dev/null 2>&1; rc=$?
check "4a rc=0"            '[[ "'"${rc}"'" -eq 0 ]]'
check "4b AUTO=0"          '[[ "${AUTO_GENERATED}" -eq 0 ]]'
check "4c Makefile made"   '[[ -f "${T}/comp/Makefile" ]]'
check "4d no Dockerfile"   '[[ ! -f "${T}/comp/Dockerfile" ]]'

echo "5 — Makefile present -> use as-is"
mkdir -p "${T}/mk"; printf 'services: {}\n' > "${T}/mk/docker-compose.yml"; printf 'up:\n\techo up\n' > "${T}/mk/Makefile"
OPS_DIR="${T}/mk"; OPS_NAME="mk"
out5="$(ensure_runnable_ops 2>&1)"; rc=$?
check "5a rc=0"            '[[ "'"${rc}"'" -eq 0 ]]'
check "5b uses existing"   'grep -q "already present" <<< "${out5}"'

echo "6 — generated Makefile has an up target AND actually parses with make"
check "6a up target"       'grep -qE "^up" "${T}/py/Makefile"'
check "6b make -n up parses (real tabs, no split recipe)" 'make -C "${T}/py" -n up >/dev/null 2>&1'
check "6c make -n help parses" 'make -C "${T}/py" -n help >/dev/null 2>&1'

echo "7 — same dir with both manifests counts once as node"
mkdir -p "${T}/both"; printf 'print(1)\n' > "${T}/both/hello.py"; printf '{}\n' > "${T}/both/package.json"
OPS_DIR="${T}/both"; detect_run_apps
check "7a one app"         '[[ "${#RUN_APP_DIR[@]}" -eq 1 ]]'
check "7b node wins"       '[[ "${RUN_APP_KIND[0]}" == node ]]'

echo "8 — multi-app repo: every app becomes a compose service (no app missing)"
R="${T}/multi"
mkdir -p "${R}/apps/python-cli" "${R}/apps/node-cli" "${R}/apps/python-backend/app" "${R}/apps/node-frontend"
printf 'print(1)\n'                            > "${R}/apps/python-cli/hello.py"
printf '{"scripts":{"start":"node hello.js"}}\n' > "${R}/apps/node-cli/package.json"; : > "${R}/apps/node-cli/hello.js"
printf 'x=1\n'                                 > "${R}/apps/python-backend/app/main.py"
printf '{}\n'                                  > "${R}/apps/node-frontend/package.json"; : > "${R}/apps/node-frontend/server.js"
OPS_DIR="${R}"; OPS_NAME="multi"; AUTO_GENERATED=0
ensure_runnable_ops >/dev/null 2>&1; rc=$?
check "8a rc=0"                  '[[ "'"${rc}"'" -eq 0 ]]'
check "8b 4 apps detected"       '[[ "${#RUN_APP_DIR[@]}" -eq 4 ]]'
check "8c compose has 4 services" '[[ "$(grep -cE "^  [a-z0-9-]+:$" "${R}/docker-compose.yml")" -eq 4 ]]'
check "8d Dockerfile per app"    '[[ "$(find "${R}/apps" -name Dockerfile | wc -l | tr -d " ")" -eq 4 ]]'
check "8e make -n up parses"     'make -C "${R}" -n up >/dev/null 2>&1'
check "8f per-service up target" 'grep -q "^up-python-cli:" "${R}/Makefile"'
check "8g python-backend present" 'grep -q "python-backend-app:" "${R}/docker-compose.yml"'

rm -rf "${T}"
echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
