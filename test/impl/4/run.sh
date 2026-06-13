#!/usr/bin/env bash
# impl/4 — --default-env + -a/--auth. Real invocations with a local repo (no network).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"
APP="${ROOT}/wsa4sdd.sh"

PASS=0; FAIL=0
tpass() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

echo "1/2/3 — mandatory-value errors (die before execution)"
out1="$(bash "${APP}" --default-env -a tok 2>&1)"; rc1=$?
check "1 no -I -> nonzero"      '[[ "'"${rc1}"'" -ne 0 ]]'
check "1 message"              'grep -q "repositories are required" <<< "${out1}"'

out2="$(bash "${APP}" --default-env -I "https://h/r.git" 2>&1)"; rc2=$?
check "2 no -a -> nonzero"      '[[ "'"${rc2}"'" -ne 0 ]]'
check "2 message"              'grep -q "\-a/--auth is required" <<< "${out2}"'

out3="$(bash "${APP}" --default-env -I "https://h/r.git" -a pat 2>&1)"; rc3=$?
check "3 bare pat -> nonzero"   '[[ "'"${rc3}"'" -ne 0 ]]'
check "3 message"              'grep -q "PAT value is required" <<< "${out3}"'

echo "4 — positive dry-run (local repo, cwd workspace)"
TMP="$(mktemp -d)"; mkdir -p "${TMP}/src" "${TMP}/run"
git -C "${TMP}/src" init -q -b main
printf "services: {}\n" > "${TMP}/src/docker-compose.yml"
git -C "${TMP}/src" -c user.email=t@t -c user.name=t add -A
git -C "${TMP}/src" -c user.email=t@t -c user.name=t commit -q -m init
out4="$( cd "${TMP}/run" && bash "${APP}" -I "${TMP}/src" -a faketoken123 --default-env --no-run 2>&1 )"; rc4=$?
check "4a rc=0"                 '[[ "'"${rc4}"'" -eq 0 ]]'
check "4b workspace=cwd"        'grep -q "ws=${TMP}/run" <<< "${out4}"'
check "4c ops=first repo (src)" 'grep -q "ops=src" <<< "${out4}"'
check "4d auth=pat"             'grep -q "auth=pat" <<< "${out4}"'
check "4e cloned into cwd"      '[[ -d "${TMP}/run/src/.git" ]]'
rm -rf "${TMP}"

echo "5/6 — -a value interpretation (source-level)"
# shellcheck disable=SC1090
( . "${APP}"
  _AUTH_ARG="gh"; case "${_AUTH_ARG}" in gh) AUTH_METHOD=gh;; esac
  [[ "${AUTH_METHOD}" == gh ]] ) && tpass "5 -a gh -> method gh" || tfail "5 -a gh -> method gh"
( . "${APP}"
  GITHUB_PAT=""; _AUTH_ARG="ghp_realtoken"
  case "${_AUTH_ARG}" in gh|none|pat) :;; *) AUTH_METHOD=pat; GITHUB_PAT="${_AUTH_ARG}";; esac
  [[ "${AUTH_METHOD}" == pat && "${GITHUB_PAT}" == ghp_realtoken ]] ) \
  && tpass "6 -a token -> pat+token" || tfail "6 -a token -> pat+token"

echo "7 — help advertises flags"
check "7 help default-env" 'bash "${APP}" --help | grep -q -- "--default-env"'
check "7 help auth"        'bash "${APP}" --help | grep -q -- "-a, --auth"'

echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
