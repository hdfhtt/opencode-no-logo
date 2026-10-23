#!/usr/bin/env sh
# opencode-no-logo installer (Linux/macOS)
# Removes the OpenCode wordmark from the TUI home/prompt screen.
#
# opencode 1.x: installs a TUI plugin that takes over the `home_logo` slot.
# opencode 2.x: that slot was removed and the wordmark is drawn inline from
#   bytecode (no slot, config flag, or theme color, and the source cannot be
#   patched). Instead the installer drops a small TUI plugin that runs inside
#   the renderer and hides the wordmark node in the live render tree. It lives
#   in your config dir, so it keeps working across opencode updates (updates
#   only replace the binary, never your config) — no re-run needed.
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"
CLI="$CFG/cli.json"
PKGDIR="$CFG/no-home-logo"

# Locate the opencode binary and read its major version.
OC="$(command -v opencode 2>/dev/null || true)"
[ -z "$OC" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OC="$HOME/.opencode/bin/opencode"
VER=""
[ -n "$OC" ] && VER="$("$OC" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
MAJOR="${VER%%.*}"

if [ -n "$MAJOR" ] && [ "$MAJOR" -ge 2 ] 2>/dev/null; then
  echo "opencode v$VER detected (2.x: installing the renderer plugin)."
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to install on opencode 2.x but was not found." >&2
    exit 1
  fi

  # The TUI plugin package. opencode loads it as a TUI plugin because its
  # package.json declares a "./tui" export; it is registered in cli.json below.
  mkdir -p "$PKGDIR"
  cat > "$PKGDIR/package.json" <<'EOF'
{
  "name": "opencode-no-home-logo",
  "version": "1.0.0",
  "type": "module",
  "exports": { "./tui": "./tui.js" }
}
EOF
  cat > "$PKGDIR/tui.js" <<'EOF'
// opencode-no-logo — hide the opencode home wordmark on opencode 2.x.
//
// On 2.x the wordmark is rendered inline: no plugin slot, no config flag, no
// dedicated theme color, and the TUI runs from Bun bytecode so the binary's
// source cannot be patched. A TUI plugin, however, runs inside the renderer
// process, so this finds the wordmark in the live render tree and hides it.
//
// The wordmark is the only thing on screen that is a block of block glyphs at
// least 3 rows tall whose subtree is nothing but block art and whitespace (the
// prompt's bottom border is one row, a work spinner is a lone glyph, and
// ordinary UI mixes in letters). So "the maximal block-art-only subtree that is
// >= 3 rows tall" picks out the wordmark and nothing else.
//
// Two cooperating hooks:
//   * A frame callback sets the node's visible=false. This is the real hide:
//     overlay-safe and layout-correct (a hidden node is not painted; the Ctrl+P
//     palette and dialogs render normally over it).
//   * A post-process pass clears the node's cells in the composited frame buffer
//     ONLY on the single frame it is created and painted before the sweep hides
//     it — gated on the node still being visible. Once hidden (steady state, and
//     under any overlay) it does nothing, so it never stamps over the palette.
//     This removes the one-frame flash on launch / return to home.

const NON_ART = /[^\u2580-\u259F\s]/ // not a block glyph and not whitespace

function textOf(node) {
  for (const k of ["plainText", "content", "text"]) {
    try { const v = node[k]; if (typeof v === "string" && v.length) return v } catch {}
  }
  try { if (typeof node.getPlainText === "function") { const v = node.getPlainText(); if (typeof v === "string") return v } } catch {}
  return ""
}
function kids(node) {
  try { if (typeof node.getChildren === "function") return node.getChildren() || [] } catch {}
  try { if (Array.isArray(node.children)) return node.children } catch {}
  return []
}

export default {
  id: "no-home-logo",
  setup: async (ctx) => {
    const r = ctx && ctx.renderer
    if (!r || !r.root) return // not the TUI renderer process — nothing to do

    const analyze = (node) => {
      const t = textOf(node)
      let art = !NON_ART.test(t)
      // Fresh regex each call: Bun's String.match keeps a stale lastIndex on a
      // shared global regex, which would undercount.
      let blocks = (t.match(/[\u2580-\u259F]/g) || []).length
      for (const c of kids(node)) {
        const a = analyze(c)
        art = art && a.art
        blocks += a.blocks
      }
      node.__art = art
      node.__blocks = blocks
      return { art, blocks }
    }

    const findLogo = () => {
      try { analyze(r.root) } catch { return null }
      const stack = [[r.root, null]]
      while (stack.length) {
        const [node, par] = stack.pop()
        if (!node) continue
        if (node.__art && node.__blocks >= 12 && (!par || !par.__art)) {
          let h = 0; try { h = node.height } catch {}
          if (h >= 3) return node
          continue
        }
        for (const c of kids(node)) stack.push([c, node])
      }
      return null
    }

    const sweep = () => {
      const node = findLogo()
      if (node && node.visible !== false) { try { node.visible = false } catch {}; return true }
      return false
    }
    try {
      r.setFrameCallback(async () => { if (sweep()) r.requestRender() })
      r.requestRender()
    } catch {}

    const clear = (buffer) => {
      const node = findLogo()
      if (!node || node.visible === false) return
      try {
        const x = node.x | 0, y = node.y | 0, w = node.width | 0, h = node.height | 0
        if (w > 0 && h > 0) buffer.fillRect(x, y, w, h, r.backgroundColor)
      } catch {}
    }
    try {
      r.addPostProcessFn(clear)
      try {
        if (ctx.lifecycle && typeof ctx.lifecycle.onDispose === "function") {
          ctx.lifecycle.onDispose(() => { try { r.removePostProcessFn(clear) } catch {} })
        }
      } catch {}
    } catch {}
  },
}
EOF

  # Register in cli.json, revert any inert binary patch from older versions, and
  # clean up the old server sync plugin / stamp / stale v1 plugin.
  python3 -I - "$CFG" "$PKGDIR" "$CLI" "$TUI" "$OC" "$ENTRY" <<'PY'
import json, os, sys
cfg, pkgdir, cli, tui, oc, entry = sys.argv[1:7]

def load(p):
    try:
        with open(p) as f: return json.load(f)
    except Exception:
        return None

# 1) Register the plugin in cli.json (merge; preserve everything else).
d = load(cli)
if not isinstance(d, dict): d = {}
d.setdefault("$schema", "https://opencode.ai/v2/cli.json")
pl = d.get("plugins")
if not isinstance(pl, list): pl = []
if pkgdir not in pl: pl.append(pkgdir)
d["plugins"] = pl
with open(cli, "w") as f: json.dump(d, f, indent=2)
print("Registered the renderer plugin in cli.json.")

# 2) Revert an inert binary patch left by older versions of this installer.
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
            print("Reverted a leftover (inert) binary patch.")
        except OSError:
            try: os.remove(tmp)
            except OSError: pass

# 3) Remove the old server sync plugin, its stamp, and any stale v1 TUI plugin.
for f in (os.path.join(cfg, "plugins", "no-logo-sync.ts"),
          os.path.join(cfg, ".no-logo-stamp"),
          os.path.join(cfg, "plugins", "no-home-logo.ts")):
    try: os.remove(f)
    except OSError: pass
t = load(tui)
if isinstance(t, dict) and isinstance(t.get("plugin"), list):
    t["plugin"] = [x for x in t["plugin"] if x != entry]
    if not t["plugin"]: t.pop("plugin", None)
    with open(tui, "w") as f: json.dump(t, f, indent=2)
PY
  echo "OpenCode wordmark removed. Restart opencode to apply."
  echo "This survives opencode updates automatically (it lives in your config)."
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
  python3 -I - "$TUI" "$ENTRY" <<'PY'
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
