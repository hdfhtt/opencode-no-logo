#!/usr/bin/env sh
# opencode-no-logo installer (Linux/macOS)
# Removes the OpenCode wordmark from the TUI home/prompt screen.
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"

mkdir -p "$CFG/plugins"

cat > "$CFG/plugins/no-home-logo.ts" <<'EOF'
export default {
  id: "no-home-logo",
  tui: async (api) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
  },
}
EOF

if command -v python3 >/dev/null 2>&1; then
  python3 - "$TUI" "$ENTRY" <<'PY'
import json, os, sys
p, e = sys.argv[1], sys.argv[2]
d = {}
if os.path.exists(p):
    try:
        d = json.load(open(p))
    except Exception:
        d = {}
if not isinstance(d, dict):
    d = {}
d.setdefault("$schema", "https://opencode.ai/tui.json")
pl = d.get("plugin")
if not isinstance(pl, list):
    pl = []
if e not in pl:
    pl.append(e)
d["plugin"] = pl
json.dump(d, open(p, "w"), indent=2)
PY
elif command -v jq >/dev/null 2>&1; then
  [ -f "$TUI" ] || printf '{}' > "$TUI"
  tmp="$(mktemp)"
  jq --arg e "$ENTRY" '(.["$schema"] //= "https://opencode.ai/tui.json") | (.plugin //= []) | (if (.plugin | index($e)) then . else .plugin += [$e] end)' "$TUI" > "$tmp" && mv "$tmp" "$TUI"
elif [ -f "$TUI" ]; then
  echo "tui.json already exists but neither python3 nor jq is available."
  echo "Add \"$ENTRY\" to its \"plugin\" array manually."
else
  printf '{\n  "$schema": "https://opencode.ai/tui.json",\n  "plugin": ["%s"]\n}\n' "$ENTRY" > "$TUI"
fi

echo "OpenCode logo removed. Restart opencode to apply."
