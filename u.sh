#!/usr/bin/env sh
# opencode-no-logo uninstaller (Linux/macOS)
# Restores the OpenCode wordmark by removing the plugin it installed.
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/u.sh | bash
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"

rm -f "$CFG/plugins/no-home-logo.ts"

if [ ! -f "$TUI" ]; then
  echo "OpenCode logo restored. Restart opencode to apply."
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$TUI" "$ENTRY" <<'PY'
import json, os, sys
p, e = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(p))
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
pl = d.get("plugin")
if isinstance(pl, list):
    pl = [x for x in pl if x != e]
    if pl:
        d["plugin"] = pl
    else:
        d.pop("plugin", None)
json.dump(d, open(p, "w"), indent=2)
PY
elif command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq --arg e "$ENTRY" 'if (.plugin | type) == "array" then (.plugin |= map(select(. != $e)) | if (.plugin | length) == 0 then del(.plugin) else . end) else . end' "$TUI" > "$tmp" && mv "$tmp" "$TUI"
else
  echo "Neither python3 nor jq is available."
  echo "Remove \"$ENTRY\" from the \"plugin\" array in $TUI manually."
fi

echo "OpenCode logo restored. Restart opencode to apply."
