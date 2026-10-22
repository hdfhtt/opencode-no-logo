#!/usr/bin/env sh
# opencode-no-logo installer (Linux/macOS)
# Removes the OpenCode wordmark from the TUI home/prompt screen.
#
# opencode 1.x: installs a TUI plugin that takes over the `home_logo` slot.
# opencode 2.x: that slot was removed, so instead the installer applies a tiny,
#   reversible, length-preserving patch to the opencode binary that makes the
#   home wordmark never render. Re-run after updating opencode (updates replace
#   the binary).
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"

# Locate the opencode binary and read its major version.
OC="$(command -v opencode 2>/dev/null || true)"
[ -z "$OC" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OC="$HOME/.opencode/bin/opencode"
VER=""
[ -n "$OC" ] && VER="$("$OC" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
MAJOR="${VER%%.*}"

if [ -n "$MAJOR" ] && [ "$MAJOR" -ge 2 ] 2>/dev/null; then
  echo "opencode v$VER detected (2.x: patching the binary)."
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to patch opencode 2.x but was not found." >&2
    exit 1
  fi
  python3 - "$OC" "$CFG" "$ENTRY" "$TUI" <<'PY'
import json, os, sys
oc, cfg, entry, tui = sys.argv[1:5]

# 1) Patch the binary: the home logo renders nothing when height<12; flipping
#    the comparison to the always-true ">-1" hides it at every size. Same byte
#    length, so the Bun standalone layout stays valid.
path = os.path.realpath(oc)
OLD, NEW = b"n().height<12", b"n().height>-1"
try:
    data = open(path, "rb").read()
except OSError as e:
    sys.stderr.write("opencode-no-logo: cannot read %s: %s\n" % (path, e)); sys.exit(1)
no, nn = data.count(OLD), data.count(NEW)
if no == 1:
    i = data.find(OLD)
    try:
        with open(path, "r+b") as f:
            f.seek(i); f.write(NEW)
    except OSError as e:
        sys.stderr.write("opencode-no-logo: cannot write %s: %s\n" % (path, e)); sys.exit(1)
    print("Removed the opencode home wordmark (%s)." % path)
elif no == 0 and nn >= 1:
    print("opencode is already patched.")
else:
    sys.stderr.write(
        "opencode-no-logo: expected one patch marker, found %d.\n"
        "This opencode build differs from the supported 2.x layout; not patching.\n" % no)
    sys.exit(1)

# 2) Remove any plugin left by an earlier 1.x install; on 2.x it only errors.
pf = os.path.join(cfg, "plugins", "no-home-logo.ts")
if os.path.exists(pf):
    os.remove(pf)
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
    print("Removed a leftover v1 plugin; its startup error will stop.")
PY
  echo "Restart opencode to apply. Re-run this installer after updating opencode."
  exit 0
fi

if [ -z "$VER" ]; then
  echo "Warning: could not determine the opencode version; installing the 1.x plugin."
fi

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
