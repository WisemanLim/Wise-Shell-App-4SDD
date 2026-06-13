#!/usr/bin/env bash
# impl/6 — /repo branch specs + multi-input. Sources app; uses a local git repo (no network).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

# shellcheck disable=SC1090
. "${ROOT}/wsa4sdd.sh"

PASS=0; FAIL=0
tpass() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

echo "1/2/3 — spec parsing"
check "1 url part"      '[[ "$(repo_url_part "https://h/r.git#dev")" == "https://h/r.git" ]]'
check "1 branch part"   '[[ "$(repo_branch_part "https://h/r.git#dev")" == "dev" ]]'
check "2 no branch"     '[[ -z "$(repo_branch_part "https://h/r.git")" ]]'
check "3 name ignores branch" '[[ "$(repo_name_from_url "https://github.com/o/name.git#feature/x")" == "name" ]]'

echo "4/5 — validity allows #branch"
check "4 ssh#branch valid"   'is_valid_repo_url "git@github.com:o/r.git#main"'
check "4 https#branch valid" 'is_valid_repo_url "https://h/o/r#release/1.0"'
check "5 bogus#dev invalid"  '! is_valid_repo_url "bogus#dev"'

echo "6 — positional multi-input (comma + space)"
INPUT_REPOS=(); handle_repo 'https://h/a#dev,https://h/b' 'git@h:o/c.git#main' >/dev/null 2>&1
check "6a 3 specs"           '[[ "${#INPUT_REPOS[@]}" -eq 3 ]]'
check "6b keeps #branch"     '[[ "${INPUT_REPOS[0]}" == "https://h/a#dev" ]]'

echo "7/8 — real clone & pull by branch (local repo)"
T="$(mktemp -d)"; SRC="${T}/src"
git init -q -b main "${SRC}"
git -C "${SRC}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m main1
git -C "${SRC}" checkout -q -b dev
echo dev > "${SRC}/devfile"
git -C "${SRC}" -c user.email=t@t -c user.name=t add -A
git -C "${SRC}" -c user.email=t@t -c user.name=t commit -q -m devcommit
git -C "${SRC}" checkout -q main
WORKSPACE_DIR="${T}/ws"; mkdir -p "${WORKSPACE_DIR}"; AUTH_METHOD=none
nm="$(sync_repo "${SRC}#dev" 2>/dev/null)"
check "7a cloned"            '[[ -d "${WORKSPACE_DIR}/src/.git" ]]'
check "7b on dev branch"     '[[ "$(git -C "${WORKSPACE_DIR}/src" rev-parse --abbrev-ref HEAD)" == dev ]]'
check "7c dev file present"  '[[ -f "${WORKSPACE_DIR}/src/devfile" ]]'
sync_repo "${SRC}#main" >/dev/null 2>&1
check "8 switched to main"   '[[ "$(git -C "${WORKSPACE_DIR}/src" rev-parse --abbrev-ref HEAD)" == main ]]'
rm -rf "${T}"

echo "9 — help advertises #branch"
check "9 welcome #branch" 'grep -q "url\[#branch\]" "${ROOT}/wsa4sdd.sh"'

echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
