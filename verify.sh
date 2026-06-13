#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# WSA4SDD App Verification Test Suite
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ANSI Styling
C_GREEN=$'\033[32m'
C_RED=$'\033[31m'
C_CYAN=$'\033[36m'
C_RST=$'\033[0m'

log() { printf '%s▶%s %s\n' "${C_CYAN}" "${C_RST}" "$*"; }
ok()  { printf '%s✓%s %s\n' "${C_GREEN}" "${C_RST}" "$*"; }
err() { printf '%s✗%s %s\n' "${C_RED}" "${C_RST}" "$*" >&2; exit 1; }

log "Starting WSA4SDD App verification tests..."

# Test 1: Verify wsa4sdd.sh is executable and parses help successfully
log "Test 1: Testing script permissions and help output..."
chmod +x wsa4sdd.sh
./wsa4sdd.sh --help | grep -q "WSA4SDD App" || err "Test 1 Failed: Help output did not contain 'WSA4SDD App'"
ok "Test 1 Passed: Help output verified successfully."

# Test 2: Verify CLI mode failure on missing required input
log "Test 2: Testing direct run failure when inputs are missing..."
if ./wsa4sdd.sh -w "/tmp/wsa4sdd-test-ws" --no-run 2>/dev/null; then
  err "Test 2 Failed: Script should have returned an error on missing -I/--input parameter"
else
  ok "Test 2 Passed: Script correctly errored on missing inputs."
fi

# Test 3: Test cache path definition and TUI commands structure
log "Test 3: Testing cache syntax and TUI command routing..."
grep -q "_CACHE=" wsa4sdd.sh || err "Test 3 Failed: Cache variable not defined in wsa4sdd.sh"
grep -q "cache_save" wsa4sdd.sh || err "Test 3 Failed: cache_save function not defined in wsa4sdd.sh"
grep -q "cache_load" wsa4sdd.sh || err "Test 3 Failed: cache_load function not defined in wsa4sdd.sh"
grep -q "cache_delete" wsa4sdd.sh || err "Test 3 Failed: cache_delete function not defined in wsa4sdd.sh"
ok "Test 3 Passed: Cache management functions found in script source."

# Test 4: Run a mock deployment with --no-run using a local temp git repo (CLI dry-run)
log "Test 4: Performing CLI dry-run verification..."
TEST_WS="/tmp/wsa4sdd-verify-ws-$$"
mkdir -p "${TEST_WS}"

# Set up a dummy local git repository to use as our target
TEST_REPO_DIR="/tmp/wsa4sdd-verify-repo-$$"
mkdir -p "${TEST_REPO_DIR}"
git -C "${TEST_REPO_DIR}" init -b main
git -C "${TEST_REPO_DIR}" config user.email "test@example.com"
git -C "${TEST_REPO_DIR}" config user.name "Test User"
echo "version: '3'" > "${TEST_REPO_DIR}/docker-compose.yml"
git -C "${TEST_REPO_DIR}" add docker-compose.yml
git -C "${TEST_REPO_DIR}" commit -m "initial commit"

# Execute wsa4sdd.sh pointing to our local dummy repo
log "Executing dry-run: ./wsa4sdd.sh -I \"${TEST_REPO_DIR}\" -w \"${TEST_WS}\" --no-run"
./wsa4sdd.sh -I "${TEST_REPO_DIR}" -w "${TEST_WS}" --no-run
ok "Test 4 Passed: CLI dry-run completed successfully."

# Clean up
rm -rf "${TEST_WS}" "${TEST_REPO_DIR}"
log "All WSA4SDD App verification tests completed successfully!"
