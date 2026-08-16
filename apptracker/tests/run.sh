#!/usr/bin/env bash
# Runs the Store persistence tests against a throwaway data directory, so a
# failing test can never touch the real applications.json.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT

cat > "$dir/applications.json" <<'JSON'
{
  "version": 1,
  "applications": [
    { "id": "old", "company": "Older Co", "role": "Sent Role", "status": "submitted" },
    { "id": "live", "company": "Live Co", "role": "Due Role", "status": "drafting",
      "due": "2099-01-01T09:30" }
  ]
}
JSON

# Quickshell resolves same-directory components only, and refuses module
# paths outside the config folder -- so assemble a throwaway config dir.
ln -s "$here/../Store.qml" "$dir/Store.qml"
ln -s "$here/../theme.js" "$dir/theme.js"
ln -s "$here/store_test.qml" "$dir/store_test.qml"

APPTRACKER_TEST_DIR="$dir" timeout 25 qs -p "$dir/store_test.qml" >"$dir/qs.log" 2>&1 || true

if [ ! -f "$dir/result.txt" ]; then
  echo "FAIL: test never wrote a result -- quickshell output follows"
  grep -vE 'Gtk-WARNING|Theme parsing|portal' "$dir/qs.log" | tail -20
  exit 1
fi

# A QML error is printed, not thrown, so a green result with errors in the log
# is still a failure.
if grep -q 'ERROR' "$dir/qs.log"; then
  echo "FAIL: QML errors during the run"
  grep -E 'ERROR' "$dir/qs.log" | head -10
  exit 1
fi

cat "$dir/result.txt"
head -1 "$dir/result.txt" | grep -q PASS
