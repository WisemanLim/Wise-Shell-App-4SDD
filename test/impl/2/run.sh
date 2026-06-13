#!/usr/bin/env bash
# impl/2 — unit tests for theme feature by sourcing wsa4sdd.sh.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

# shellcheck disable=SC1090
. "${ROOT}/wsa4sdd.sh"

PASS=0; FAIL=0
tpass() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
tfail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check() { if eval "$2"; then tpass "$1"; else tfail "$1"; fi; }

echo "1 — apply all 6 themes"
for t in dark light dark-daltonized light-daltonized dark-ansi light-ansi; do
  apply_theme "$t"
  check "apply ${t}" '[[ "${THEME}" == "'"$t"'" && -n "${C_GREEN}" && -n "${C_RED}" ]]'
done

echo "2 — invalid theme falls back to dark"
apply_theme bogus
check "bogus -> dark" '[[ "${THEME}" == dark ]]'

echo "3 — labels"
check "label dark"             '[[ "$(theme_label dark)" == "Dark" ]]'
check "label dark-daltonized"  '[[ "$(theme_label dark-daltonized)" == *colorblind* ]]'
check "label light-ansi"       '[[ "$(theme_label light-ansi)" == *"ANSI 16-color"* ]]'

echo "4/5 — handle_theme positional"
_THEME_SET=0
handle_theme light >/dev/null 2>&1
check "4 set light + flag"      '[[ "${THEME}" == light && "${_THEME_SET}" -eq 1 ]]'
out5="$(handle_theme nope 2>&1)"
check "5 invalid warns"         'grep -qi "Unknown theme" <<< "${out5}"'

echo "6 — theme cache round-trip + survives session cache deletion"
apply_theme dark-ansi; _THEME_SET=1; theme_save
THEME="dark"; _THEME_SET=0
theme_load
check "6a theme restored"       '[[ "${THEME}" == dark-ansi ]]'
check "6b flag restored"        '[[ "${_THEME_SET}" -eq 1 ]]'
# session cache deletion must NOT remove the theme cache
cache_save 2>/dev/null; cache_delete
check "6c theme cache survives" '[[ -f "${_THEME_CACHE}" ]]'
THEME="light"; _THEME_SET=0; theme_load
check "6d still dark-ansi after delete" '[[ "${THEME}" == dark-ansi ]]'
rm -f "${_THEME_CACHE}"

echo "7 — first-run gate (no prompt when set)"
_THEME_SET=1
first_run_theme >/dev/null 2>&1
check "7 returns immediately"   '[[ $? -eq 0 ]]'

echo "8 — status shows Theme line"
INPUT_REPOS=(); WORKSPACE_DIR=""; AUTH_METHOD=""; BOOTSTRAP_DONE=0
out8="$(handle_status 2>&1)"
check "8 Theme line present"    'grep -q "Theme" <<< "${out8}"'

echo "9 — registration in source"
check "9 dispatcher /theme|/T"  'grep -q "/theme|/T)" "${ROOT}/wsa4sdd.sh"'
check "9 autocomplete /theme"   'grep -q "\"/theme\"" "${ROOT}/wsa4sdd.sh"'
check "9 help line"             'grep -q "/theme, /T" "${ROOT}/wsa4sdd.sh"'

echo "-------------------------------------------"
printf "RESULT: %d passed, %d failed\n" "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
