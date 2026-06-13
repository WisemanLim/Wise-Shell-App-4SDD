#!/bin/bash
# Orchestrates: clean -> record (asciinema+expect) -> redact -> render mp4.
# All generated artifacts (cast/gif/mp4 + scripts) live under this directory.
set -uo pipefail

EXEC="/Users/wise/Developer/NGL(Go,Rust,...)/Wise-Shell-App-4SDD"
REC="${EXEC}/Usage-Records"
WSBASE="/Users/wise/Developer/tmp/WSA4SDD"
UIDN="$(id -u)"
export COLUMNS=120 LINES=34

echo "== clean state =="
rm -f "/tmp/.wsa4sdd-${UIDN}.cache" /tmp/.wsa4sdd_history
printf 'CACHE_THEME=dark\n' > "/tmp/.wsa4sdd-theme-${UIDN}.cache"
chmod 600 "/tmp/.wsa4sdd-theme-${UIDN}.cache"

# Fresh workspace + remove any leftover demo containers/ports.
rm -rf "$WSBASE"
mkdir -p "$WSBASE"
docker rm -f $(docker ps -aq --filter "name=wsa4sdd") 2>/dev/null || true

echo "== record =="
asciinema rec \
  --headless \
  --overwrite \
  --window-size 120x34 \
  -c "expect '${REC}/drive.exp'" \
  "${REC}/WSA4SDD.cast"
echo "record exit: $?"

echo "== redact =="
python3 "${REC}/redact.py" "${REC}/WSA4SDD.cast" "${REC}/WSA4SDD.clean.cast"

# Safety gate: abort if any /Users path or token survived redaction.
if grep -qE '/Users/|gh[opsru]_[A-Za-z0-9]{6,}' "${REC}/WSA4SDD.clean.cast"; then
  echo "!! LEAK DETECTED in clean cast — aborting before render" >&2
  grep -onE '/Users/[^"\\ ]*|gh[opsru]_[A-Za-z0-9]{6,}' "${REC}/WSA4SDD.clean.cast" | head >&2
  exit 3
fi
echo "redaction verified clean"

echo "== render gif =="
agg --idle-time-limit 1.2 --speed 1.6 --font-size 16 --fps-cap 24 \
  "${REC}/WSA4SDD.clean.cast" "${REC}/WSA4SDD.gif"

echo "== gif -> mp4 =="
ffmpeg -y -i "${REC}/WSA4SDD.gif" \
  -movflags +faststart -pix_fmt yuv420p \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  "${REC}/WSA4SDD.mp4"

echo "== done =="
ls -la "${REC}/WSA4SDD.mp4"
