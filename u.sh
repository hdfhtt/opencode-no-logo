#!/usr/bin/env sh
# opencode-no-logo uninstaller (Linux/macOS)
# Restores the OpenCode wordmark.
#   opencode 1.x: removes the plugin it installed.
#   opencode 2.x: reverts the binary patch.
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/u.sh | bash
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"

OC="$(command -v opencode 2>/dev/null || true)"
[ -z "$OC" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OC="$HOME/.opencode/bin/opencode"

if command -v python3 >/dev/null 2>&1; then
  python3 - "$OC" "$CFG" "$ENTRY" "$TUI" <<'PY'
import json, os, sys
oc, cfg, entry, tui = sys.argv[1:5]

# 1) Revert the binary patch if present (no-op otherwise).
if oc:
    path = os.path.realpath(oc)
    PATCHED, ORIG = b"n().height>-1", b"n().height<12"
    try:
        data = open(path, "rb").read()
    except OSError:
        data = None
    if data is not None and data.count(PATCHED) == 1 and data.count(ORIG) == 0:
        i = data.find(PATCHED)
        try:
            with open(path, "r+b") as f:
                f.seek(i); f.write(ORIG)
            print("Reverted the opencode binary patch (%s)." % path)
        except OSError as e:
            sys.stderr.write("opencode-no-logo: cannot write %s: %s\n" % (path, e))

# 2) Remove the 1.x plugin, its tui.json entry, and any leftover motd.txt.
pf = os.path.join(cfg, "plugins", "no-home-logo.ts")
if os.path.exists(pf):
    os.remove(pf)
motd = os.path.join(cfg, "motd.txt")
if os.path.exists(motd):
    os.remove(motd)
if os.path.exists(tui):
    try:
        d = json.load(open(tui))
    except Exception:
        d = None
    if isinstance(d, dict) and isinstance(d.get("plugin"), list):
        d["plugin"] = [x for x in d["plugin"] if x != entry]
        if not d["plugin"]:
            d.pop("plugin", None)
        json.dump(d, open(tui, "w"), indent=2)
PY
else
  # Fallback without python3: plugin/tui cleanup only; a 2.x binary patch cannot be reverted here.
  rm -f "$CFG/plugins/no-home-logo.ts" "$CFG/motd.txt"
  if [ -f "$TUI" ] && command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg e "$ENTRY" 'if (.plugin | type) == "array" then (.plugin |= map(select(. != $e)) | if (.plugin | length) == 0 then del(.plugin) else . end) else . end' "$TUI" > "$tmp" && mv "$tmp" "$TUI"
  fi
  echo "Note: python3 not found; if you are on opencode 2.x, reinstall opencode to restore the logo."
fi

echo "OpenCode logo restored. Restart opencode to apply."
