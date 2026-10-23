#!/usr/bin/env sh
# opencode-no-logo uninstaller (Linux/macOS)
# Restores the OpenCode wordmark.
#   opencode 1.x: removes the TUI plugin it installed.
#   opencode 2.x: removes the renderer plugin and its cli.json registration.
# Also cleans up anything left by older versions of this tool (an inert binary
# patch, the server sync plugin, and its stamp).
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/u.sh | bash
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"
CLI="$CFG/cli.json"
PKGDIR="$CFG/no-home-logo"

OC="$(command -v opencode 2>/dev/null || true)"
[ -z "$OC" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OC="$HOME/.opencode/bin/opencode"

if command -v python3 >/dev/null 2>&1; then
  python3 -I - "$CFG" "$PKGDIR" "$CLI" "$TUI" "$OC" "$ENTRY" <<'PY'
import json, os, shutil, sys
cfg, pkgdir, cli, tui, oc, entry = sys.argv[1:7]

def load(p):
    try:
        with open(p) as f: return json.load(f)
    except Exception:
        return None

# 1) Remove the 2.x renderer plugin registration from cli.json, and the package.
d = load(cli)
if isinstance(d, dict) and isinstance(d.get("plugins"), list):
    d["plugins"] = [x for x in d["plugins"] if x != pkgdir]
    if not d["plugins"]: d.pop("plugins", None)
    with open(cli, "w") as f: json.dump(d, f, indent=2)
try: shutil.rmtree(pkgdir)
except OSError: pass

# 2) Revert an inert binary patch left by older versions (no-op otherwise).
if oc:
    path = os.path.realpath(oc)
    try:
        data = open(path, "rb").read()
    except OSError:
        data = None
    if data is not None and data.count(b"n().height>-1") == 1 and data.count(b"n().height<12") == 0:
        rev = data.replace(b"n().height>-1", b"n().height<12")
        dirn = os.path.dirname(path)
        tmp = os.path.join(dirn, ".opencode-nologo.%d.tmp" % os.getpid())
        try:
            with open(tmp, "wb") as f: f.write(rev)
            os.chmod(tmp, os.stat(path).st_mode)
            os.replace(tmp, path)
            print("Reverted the opencode binary patch.")
        except OSError:
            try: os.remove(tmp)
            except OSError: pass

# 3) Remove the 1.x plugin (and its custom-text font/text), old server sync
#    plugin, stamp, motd, and tui entry.
for f in (os.path.join(cfg, "plugins", "no-home-logo.ts"),
          os.path.join(cfg, "plugins", "font.json"),
          os.path.join(cfg, "plugins", "text.txt"),
          os.path.join(cfg, "plugins", "no-logo-sync.ts"),
          os.path.join(cfg, ".no-logo-stamp"),
          os.path.join(cfg, "motd.txt")):
    try: os.remove(f)
    except OSError: pass
t = load(tui)
if isinstance(t, dict) and isinstance(t.get("plugin"), list):
    t["plugin"] = [x for x in t["plugin"] if x != entry]
    if not t["plugin"]: t.pop("plugin", None)
    with open(tui, "w") as f: json.dump(t, f, indent=2)
PY
else
  # Fallback without python3: file cleanup only. A cli.json plugins entry or an
  # inert 2.x binary patch must be undone by hand or by reinstalling opencode.
  rm -rf "$PKGDIR"
  rm -f "$CFG/plugins/no-home-logo.ts" "$CFG/plugins/font.json" "$CFG/plugins/text.txt" "$CFG/plugins/no-logo-sync.ts" "$CFG/.no-logo-stamp" "$CFG/motd.txt"
  if command -v jq >/dev/null 2>&1; then
    [ -f "$CLI" ] && { tmp="$(mktemp)"; jq --arg p "$PKGDIR" 'if (.plugins|type)=="array" then (.plugins |= map(select(. != $p)) | if (.plugins|length)==0 then del(.plugins) else . end) else . end' "$CLI" > "$tmp" && mv "$tmp" "$CLI"; }
    [ -f "$TUI" ] && { tmp="$(mktemp)"; jq --arg e "$ENTRY" 'if (.plugin|type)=="array" then (.plugin |= map(select(. != $e)) | if (.plugin|length)==0 then del(.plugin) else . end) else . end' "$TUI" > "$tmp" && mv "$tmp" "$TUI"; }
  else
    echo "Note: python3/jq not found; remove \"$PKGDIR\" from the \"plugins\" array in $CLI by hand."
  fi
fi

echo "OpenCode logo restored. Restart opencode to apply."
