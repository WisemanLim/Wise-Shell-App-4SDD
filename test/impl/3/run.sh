#!/usr/bin/env bash
# impl/3 — bootstrap must NOT reach [DONE] when a step fails. Uses stubs (no network).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

# shellcheck disable=SC1090
. "${ROOT}/wsa4sdd.sh"

PASS=0; FAIL=0
tpass() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

# Stub heavy/networked steps so we test control flow only.
system_env_check()    { :; }
pre_install_deps()    { return 0; }
resolve_ops_dir()     { OPS_NAME="ok"; OPS_DIR="/tmp"; CONF_FILE="/tmp/.x.conf"; return 0; }
ensure_runnable_ops() { return 0; }

echo "1/2 — sync_all_repos aggregation"
sync_repo() { case "$1" in *bad*) cerr "boom" >&2; return 1 ;; *) printf 'repoX\n' ;; esac; }
INPUT_REPOS=("https://h/good" "https://h/bad"); WORKSPACE_DIR="/tmp"
sync_all_repos >/dev/null 2>&1; rc1=$?; check "1 partial fail -> nonzero" '[[ "'"${rc1}"'" -ne 0 ]]'
INPUT_REPOS=("https://h/good1" "https://h/good2")
sync_all_repos >/dev/null 2>&1; rc2=$?; check "2 all ok -> zero" '[[ "'"${rc2}"'" -eq 0 ]]'

echo "3/4 — handle_bootstrap aborts on sync failure (no [DONE])"
sync_repo() { case "$1" in *bad*) cerr "boom" >&2; return 1 ;; *) printf 'repoX\n' ;; esac; }
INPUT_REPOS=("https://h/good" "https://h/bad"); WORKSPACE_DIR="/tmp"; AUTH_METHOD="none"; BOOTSTRAP_DONE=0
handle_bootstrap >/dev/null 2>&1; rc3=$?
check "3a returns nonzero"        '[[ "'"${rc3}"'" -ne 0 ]]'
check "3b BOOTSTRAP_DONE stays 0" '[[ "${BOOTSTRAP_DONE}" -eq 0 ]]'
check "4 status PENDING"          '[[ "$(bootstrap_status_str)" == PENDING ]]'

echo "5 — handle_bootstrap succeeds when every step passes"
sync_repo() { printf 'repoX\n'; }
INPUT_REPOS=("https://h/good"); WORKSPACE_DIR="/tmp"; AUTH_METHOD="none"; BOOTSTRAP_DONE=0
handle_bootstrap >/dev/null 2>&1; rc5=$?
check "5a returns zero"           '[[ "'"${rc5}"'" -eq 0 ]]'
check "5b BOOTSTRAP_DONE=1"       '[[ "${BOOTSTRAP_DONE}" -eq 1 ]]'
check "5c status DONE"            '[[ "$(bootstrap_status_str)" == DONE ]]'

echo "6 — clone-fail path uses return, not die"
check "6 no die in sync_repo clone-fail" \
  'awk "/^sync_repo\\(\\)/{f=1} f&&/Clone failed for|return 1   # signal/{print} /^}/{if(f)exit}" "${ROOT}/wsa4sdd.sh" | grep -q "return 1"'

echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
