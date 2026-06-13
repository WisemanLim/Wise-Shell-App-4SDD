#!/usr/bin/env bash
# impl/1 — unit tests for state logic (Req 1,2,4,5,6) by sourcing wsa4sdd.sh.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

# Source the app without running main (source guard added in wsa4sdd.sh).
# shellcheck disable=SC1090
. "${ROOT}/wsa4sdd.sh"

# Define test helpers AFTER sourcing (the app defines its own ok()/err()).
PASS=0; FAIL=0
tpass()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check()  { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

echo "Req 1 — module separation"
check "system_env_check defined" '[[ "$(type -t system_env_check)" == function ]]'
check "pre_install_deps defined" '[[ "$(type -t pre_install_deps)" == function ]]'

echo "Req 2 — repo validity / NOT SET"
INPUT_REPOS=()
check "2a empty repos -> not set"        '! repo_is_set'
check "2b invalid url rejected"          '! is_valid_repo_url "foo"'
check "2c https valid"                   'is_valid_repo_url "https://github.com/o/r"'
check "2c git@ valid"                    'is_valid_repo_url "git@github.com:o/r.git"'
check "2c local path valid"              'is_valid_repo_url "/tmp"'
INPUT_REPOS=("foo" "bar")
check "2d invalid-only -> 0 valid"       '[[ "$(count_valid_repos)" -eq 0 ]]'
check "2d invalid-only -> not set"       '! repo_is_set'
INPUT_REPOS=("https://github.com/o/r")
check "2d one valid -> set"              'repo_is_set'

echo "Req 4 — auth 4 actions"
check "auth_gh_status defined"   '[[ "$(type -t auth_gh_status)" == function ]]'
check "auth_gh_switch defined"   '[[ "$(type -t auth_gh_switch)" == function ]]'
check "auth_gh_login defined"    '[[ "$(type -t auth_gh_login)" == function ]]'
check "auth_pat_register defined" '[[ "$(type -t auth_pat_register)" == function ]]'

echo "Req 5 — bootstrap derived state"
INPUT_REPOS=("https://github.com/o/r"); WORKSPACE_DIR=""; AUTH_METHOD=""; BOOTSTRAP_DONE=0
check "5a missing ws/auth -> PENDING"    '[[ "$(bootstrap_status_str)" == PENDING ]]'
WORKSPACE_DIR="/tmp"; AUTH_METHOD="gh"
check "5c all set, not run -> PENDING"   '[[ "$(bootstrap_status_str)" == PENDING ]]'
BOOTSTRAP_DONE=1
check "5b all set + done -> DONE"        '[[ "$(bootstrap_status_str)" == DONE ]]'
# 5d: bootstrap refuses when a prerequisite is missing (no install attempted)
WORKSPACE_DIR=""; AUTH_METHOD=""; BOOTSTRAP_DONE=0
out5d="$(handle_bootstrap 2>&1)"; rc5d=$?
check "5d refuses (nonzero)"             '[[ "'"${rc5d}"'" -ne 0 ]]'
check "5d shows NOT SET"                 'grep -q "\[NOT SET\]" <<< "${out5d}"'

echo "Req 6 — dist-run gate (no auto-bootstrap, no execution)"
INPUT_REPOS=("https://github.com/o/r"); WORKSPACE_DIR=""; AUTH_METHOD=""; BOOTSTRAP_DONE=0
out6="$(handle_dist_run 2>&1)"; rc6=$?
check "6a aborts (nonzero)"              '[[ "'"${rc6}"'" -ne 0 ]]'
check "6a guides to /bootstrap"          'grep -qi "bootstrap" <<< "${out6}"'
check "6a shows NOT SET info"            'grep -q "\[NOT SET\]" <<< "${out6}"'
check "6b did not run make/deploy"       '! grep -qi "Executing: make" <<< "${out6}"'

echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
