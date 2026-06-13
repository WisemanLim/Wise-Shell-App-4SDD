#!/usr/bin/env bash
# impl/7 — python build-context = manifest dir + uvicorn CMD. Source-level, no network.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

# shellcheck disable=SC1090
. "${ROOT}/wsa4sdd.sh"

PASS=0; FAIL=0
tpass() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

# Index of an app by service name.
_idx() { local n="$1" i; for ((i=0;i<${#RUN_APP_NAME[@]};i++)); do [[ "${RUN_APP_NAME[$i]}" == "$n" ]] && { echo "$i"; return; }; done; echo -1; }

T="$(mktemp -d)"

echo "1/2/3 — FastAPI backend: manifest dir is build context, uvicorn CMD"
R="${T}/repo"; mkdir -p "${R}/apps/python-backend/app"
printf '[project]\nname="b"\ndependencies=["fastapi","uvicorn"]\n' > "${R}/apps/python-backend/pyproject.toml"
printf 'from fastapi import FastAPI\napp = FastAPI()\n' > "${R}/apps/python-backend/app/main.py"
: > "${R}/apps/python-backend/app/__init__.py"
OPS_DIR="${R}"; OPS_NAME="repo"; AUTO_GENERATED=0
ensure_runnable_ops >/dev/null 2>&1
bi="$(_idx python-backend)"
check "1a app named python-backend"        '[[ "${bi}" -ge 0 ]]'
check "1b build ctx = manifest dir"        '[[ "${RUN_APP_DIR[${bi}]}" == "${R}/apps/python-backend" ]]'
check "1c uvicorn CMD app.main:app"        'printf "%s" "${RUN_APP_ENTRY[${bi}]}" | grep -q "uvicorn.*app.main:app"'
check "1d port 8000"                       '[[ "${RUN_APP_PORT[${bi}]}" == "8000" ]]'
check "2a Dockerfile at python-backend"    '[[ -f "${R}/apps/python-backend/Dockerfile" ]]'
check "2b Dockerfile EXPOSE 8000"          'grep -q "EXPOSE 8000" "${R}/apps/python-backend/Dockerfile"'
check "2c guarantees fastapi/uvicorn"      'grep -q "pip install --no-cache-dir fastapi" "${R}/apps/python-backend/Dockerfile"'
check "2d COPY includes manifest (build .)" 'grep -q "build: apps/python-backend$" "${R}/docker-compose.yml"'
check "3 compose publishes port"           'grep -A3 "python-backend:" "${R}/docker-compose.yml" | grep -q "ports:"'

echo "4/5 — entry finder & cmd builder"
D="${T}/m"; mkdir -p "${D}/app"; printf '[project]\nname=x\n' > "${D}/pyproject.toml"; printf 'x=1\n' > "${D}/app/main.py"
check "4 finds app/main.py"        '[[ "$(_find_python_entry "${D}")" == "app/main.py" ]]'
check "5 non-fastapi -> python cmd" '[[ "$(_python_cmd_for "${D}" "app/main.py")" == "[\"python\",\"app/main.py\"]|" ]]'

echo "6 — standalone hello.py (no manifest)"
S="${T}/s"; mkdir -p "${S}"; printf 'print(1)\n' > "${S}/hello.py"
OPS_DIR="${S}"; OPS_NAME=s; detect_run_apps
check "6a one python app"   '[[ "${#RUN_APP_DIR[@]}" -eq 1 && "${RUN_APP_KIND[0]}" == python ]]'
check "6b CMD python hello" '[[ "${RUN_APP_ENTRY[0]}" == "[\"python\",\"hello.py\"]" ]]'

echo "7 — nested entry under manifest dir not double-counted"
N="${T}/n"; mkdir -p "${N}/svc/app"
printf '[project]\nname=y\n' > "${N}/svc/pyproject.toml"; printf 'x=1\n' > "${N}/svc/app/main.py"
OPS_DIR="${N}"; OPS_NAME=n; detect_run_apps
check "7 one app (manifest dir)" '[[ "${#RUN_APP_DIR[@]}" -eq 1 && "${RUN_APP_DIR[0]}" == "${N}/svc" ]]'

rm -rf "${T}"
echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
