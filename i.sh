#!/usr/bin/env sh
# opencode-no-logo installer (Linux/macOS)
# Removes the OpenCode wordmark from the TUI home/prompt screen, or replaces it
# with custom text of your choosing.
#
# opencode 1.x: installs a TUI plugin that takes over the `home_logo` slot.
# opencode 2.x: that slot was removed and the wordmark is drawn inline from
#   bytecode (no slot, config flag, or theme color, and the source cannot be
#   patched). Instead the installer drops a small TUI plugin that runs inside
#   the renderer and rewrites the wordmark node in the live render tree. It lives
#   in your config dir, so it keeps working across opencode updates (updates
#   only replace the binary, never your config) — no re-run needed.
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
#   Non-interactive: set NOLOGO_MODE=remove|text before the pipe to skip the
#   prompt, and NOLOGO_TEXT="your words" to supply the custom text.
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"
CLI="$CFG/cli.json"
PKGDIR="$CFG/no-home-logo"

b=$(printf '\033[1m'); dm=$(printf '\033[2m'); cy=$(printf '\033[36m'); rc=$(printf '\033[0m')

# Resolve mode: env override -> interactive prompt -> default "remove".
# Probe /dev/tty in a subshell first: a redirection failure on `exec` is fatal
# in POSIX sh, but only kills the subshell, so no controlling terminal (CI,
# sandboxes, some pipes) falls through to the default instead of aborting.
MODE="${NOLOGO_MODE:-}"
TEXT="${NOLOGO_TEXT:-}"
if [ -z "$MODE" ] && (exec 3<>/dev/tty) 2>/dev/null; then
  {
    printf '\n'
    printf '  %sopencode-no-logo%s\n' "$b" "$rc"
    printf '  %sChoose what shows on the opencode home screen.%s\n\n' "$dm" "$rc"
    printf '    %s1%s  Remove the logo    %s(default)%s\n' "$cy" "$rc" "$dm" "$rc"
    printf '    %s2%s  Show custom text   %syour own word or phrase%s\n\n' "$cy" "$rc" "$dm" "$rc"
  } > /dev/tty
  while :; do
    printf '  %sChoice [1/2]:%s ' "$b" "$rc" > /dev/tty
    read ans < /dev/tty || { ans=""; break; }
    case "$ans" in
      ""|1|remove) MODE=remove; break ;;
      2|t|text) MODE=text; break ;;
      *) printf '  %sPlease enter 1 or 2.%s\n' "$dm" "$rc" > /dev/tty ;;
    esac
  done
fi
[ "$MODE" = "text" ] || MODE=remove

# For custom text, resolve the phrase: env override -> prompt -> default.
if [ "$MODE" = "text" ] && [ -z "$TEXT" ] && (exec 3<>/dev/tty) 2>/dev/null; then
  while [ -z "$TEXT" ]; do
    printf '  %sEnter the text to display:%s ' "$b" "$rc" > /dev/tty
    IFS= read -r TEXT < /dev/tty || { TEXT=""; break; }
  done
fi
[ "$MODE" = "text" ] && [ -z "$TEXT" ] && TEXT="opencode"

# Locate the opencode binary and read its major version.
OC="$(command -v opencode 2>/dev/null || true)"
[ -z "$OC" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OC="$HOME/.opencode/bin/opencode"
VER=""
[ -n "$OC" ] && VER="$("$OC" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
MAJOR="${VER%%.*}"

# The cfonts "tiny" font (full A-Z/0-9), used to draw custom text in the same
# compact half-block style as opencode's own wordmark. Shared by both paths.
write_font() {
  cat > "$1" <<'EOF'
{
  "name": "tiny",
  "version": "0.2.0",
  "homepage": "https://github.com/dominikwilkowski/cfonts",
  "colors": 1,
  "lines": 2,
  "buffer": ["", ""],
  "letterspace": [" ", " "],
  "letterspace_size": 1,
  "chars": {
    "A": ["▄▀█", "█▀█"],
    "B": ["█▄▄", "█▄█"],
    "C": ["█▀▀", "█▄▄"],
    "D": ["█▀▄", "█▄▀"],
    "E": ["█▀▀", "██▄"],
    "F": ["█▀▀", "█▀ "],
    "G": ["█▀▀", "█▄█"],
    "H": ["█ █", "█▀█"],
    "I": ["█", "█"],
    "J": ["  █", "█▄█"],
    "K": ["█▄▀", "█ █"],
    "L": ["█  ", "█▄▄"],
    "M": ["█▀▄▀█", "█ ▀ █"],
    "N": ["█▄ █", "█ ▀█"],
    "O": ["█▀█", "█▄█"],
    "P": ["█▀█", "█▀▀"],
    "Q": ["█▀█", "▀▀█"],
    "R": ["█▀█", "█▀▄"],
    "S": ["█▀▀", "▄▄█"],
    "T": ["▀█▀", " █ "],
    "U": ["█ █", "█▄█"],
    "V": ["█ █", "▀▄▀"],
    "W": ["█ █ █", "▀▄▀▄▀"],
    "X": ["▀▄▀", "█ █"],
    "Y": ["█▄█", " █ "],
    "Z": ["▀█", "█▄"],
    "0": ["▞█▚", "▚█▞"],
    "1": ["▄█", " █"],
    "2": ["▀█", "█▄"],
    "3": ["▀▀█", "▄██"],
    "4": ["█ █", "▀▀█"],
    "5": ["█▀", "▄█"],
    "6": ["█▄▄", "█▄█"],
    "7": ["▀▀█", "  █"],
    "8": ["███", "█▄█"],
    "9": ["█▀█", "▀▀█"],
    "!": ["█", "▄"],
    "?": ["▀█", " ▄"],
    ".": [" ", "▄"],
    "+": ["▄█▄", " ▀ "],
    "-": ["▄▄", "  "],
    "_": ["  ", "▄▄"],
    "=": ["▀▀", "▀▀"],
    "@": ["▛█▜", "▙▟▃"],
    "#": ["▟▄▙", "▜▀▛"],
    "$": ["▖█▗", "▘█▝"],
    "%": ["▀ ▄▀", "▄▀ ▄"],
    "&": ["▄▄█", "█▄█"],
    "(": ["▄▀", "▀▄"],
    ")": ["▀▄", "▄▀"],
    "/": ["  ▄▀", "▄▀  "],
    ":": ["▀", "▄"],
    ";": ["  ", "▄▀"],
    ",": [" ", "█"],
    "'": ["▀", " "],
    "\"": ["▛ ▜", "   "],
    " ": [" ", " "]
  }
}
EOF
}

if [ -n "$MAJOR" ] && [ "$MAJOR" -ge 2 ] 2>/dev/null; then
  if [ "$MODE" = "text" ]; then
    echo "opencode v$VER detected (2.x: installing the renderer plugin, custom text)."
  else
    echo "opencode v$VER detected (2.x: installing the renderer plugin)."
  fi
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

  if [ "$MODE" = "text" ]; then
    write_font "$PKGDIR/font.json"
    printf '%s' "$TEXT" > "$PKGDIR/text.txt"
    cat > "$PKGDIR/tui.js" <<'EOF'
// opencode-no-logo — replace the opencode home wordmark with custom text on 2.x.
//
// On 2.x the wordmark is rendered inline: no plugin slot, no config flag, no
// dedicated theme color, and the TUI runs from Bun bytecode so the binary's
// source cannot be patched. A TUI plugin, however, runs inside the renderer
// process, so this finds the wordmark in the live render tree, hides it, and
// paints custom text in its place.
//
// The wordmark is the only thing on screen that is a block of block glyphs at
// least 3 rows tall whose subtree is nothing but block art and whitespace, so
// "the maximal block-art-only subtree that is >= 3 rows tall" picks it out.
//
// The custom text is drawn in cfonts' "tiny" font (full alphabet) — the same
// compact half-block style as opencode's own wordmark — into the composited
// frame buffer, centred where the wordmark sat. A z-index guard skips painting
// whenever an overlay (Ctrl+P palette, a dialog) covers the home screen, so the
// text never stamps over them.

import FONT from "./font.json" with { type: "json" }
import * as fs from "node:fs"
import { fileURLToPath } from "node:url"

const TEXT = (() => {
  try {
    const p = fileURLToPath(new URL("./text.txt", import.meta.url))
    const s = fs.readFileSync(p, "utf8").replace(/\r?\n$/, "")
    return s || "opencode"
  } catch { return "opencode" }
})()
const NON_ART = /[^\u2580-\u259F\s]/

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

const TAG = /<\/?c\d+>/g
function glyph(ch) { return FONT.chars[ch.toUpperCase()] || FONT.chars[" "] || [" ", " "] }
function glyphWidth(g) { return (g[0] || "").replace(TAG, "").length }
function measure(text) {
  let w = 0
  for (let i = 0; i < text.length; i++) {
    w += glyphWidth(glyph(text[i]))
    if (i < text.length - 1) w += FONT.letterspace_size
  }
  return { width: w, height: FONT.lines }
}

export default {
  id: "no-home-logo",
  setup: async (ctx) => {
    const r = ctx && ctx.renderer
    if (!r || !r.root) return // not the TUI renderer process — nothing to do

    // Theme-aware foreground, built from the renderer's own RGBA class.
    const fg = (() => {
      try {
        const C = r.backgroundColor.constructor
        const df = typeof C.defaultForeground === "function" ? C.defaultForeground() : C.defaultForeground
        if (df && typeof df === "object") return df
        return C.fromInts(255, 255, 255, 255)
      } catch { return r.backgroundColor }
    })()

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

    // An overlay (command palette, dialog) renders in a higher z-index layer
    // that covers the home screen while the logo node stays mounted beneath it.
    // Paint only when nothing outside the logo's own container chain covers its
    // centre with a higher z-index, so custom text never stamps over overlays.
    const zOf = (n) => { try { return (n.zIndex != null ? n.zIndex : n._zIndex) | 0 } catch { return 0 } }
    const covered = (logo) => {
      let x, y, w, h
      try { x = logo.x | 0; y = logo.y | 0; w = logo.width | 0; h = logo.height | 0 } catch { return true }
      const cx = x + (w >> 1), cy = y + (h >> 1)
      const chain = new Set([logo])
      try { let a = logo; while (a.parent) { a = a.parent; chain.add(a) } } catch {}
      const sub = new Set()
      const mark = (n) => { sub.add(n); for (const c of kids(n)) mark(c) }
      mark(logo)
      const lz = zOf(logo)
      let hit = false
      const walk = (n) => {
        if (hit || !n) return
        let vis = true; try { vis = n.visible !== false } catch {}
        if (!vis) return
        if (!chain.has(n) && !sub.has(n) && zOf(n) > lz) {
          let nx, ny, nw, nh
          try { nx = n.x | 0; ny = n.y | 0; nw = n.width | 0; nh = n.height | 0 } catch { nw = 0 }
          if (nw > 0 && nh > 0 && cx >= nx && cx < nx + nw && cy >= ny && cy < ny + nh) { hit = true; return }
        }
        for (const c of kids(n)) walk(c)
      }
      try { walk(r.root) } catch {}
      return hit
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

    const paint = (buffer) => {
      const node = findLogo()
      if (!node || covered(node)) return
      let x, y, w, h
      try { x = node.x | 0; y = node.y | 0; w = node.width | 0; h = node.height | 0 } catch { return }
      if (w <= 0 || h <= 0) return

      const m = measure(TEXT)
      const bg = r.backgroundColor
      const ox = x + Math.max(0, Math.floor((w - m.width) / 2))
      const oy = y + Math.max(0, Math.floor((h - m.height) / 2))

      try { buffer.fillRect(x, y, w, h, bg) } catch {}
      for (let i = 0, cx = ox; i < TEXT.length; i++) {
        const g = glyph(TEXT[i])
        for (let row = 0; row < FONT.lines; row++) {
          const line = (g[row] || "").replace(TAG, "")
          for (let col = 0; col < line.length; col++) {
            const chr = line[col]
            if (chr !== " ") {
              try { buffer.setCellWithAlphaBlending(cx + col, oy + row, chr, fg, bg) } catch {}
            }
          }
        }
        cx += glyphWidth(g) + FONT.letterspace_size
      }
    }
    try {
      r.addPostProcessFn(paint)
      try {
        if (ctx.lifecycle && typeof ctx.lifecycle.onDispose === "function") {
          ctx.lifecycle.onDispose(() => { try { r.removePostProcessFn(paint) } catch {} })
        }
      } catch {}
    } catch {}
  },
}
EOF
  else
    # Remove mode: drop any custom-text leftovers so re-running cleanly switches.
    rm -f "$PKGDIR/font.json" "$PKGDIR/text.txt"
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
  fi

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
  if [ "$MODE" = "text" ]; then
    echo "Custom text installed. Edit $PKGDIR/text.txt to change it. Restart opencode to apply."
  else
    echo "OpenCode wordmark removed. Restart opencode to apply."
  fi
  echo "This survives opencode updates automatically (it lives in your config)."
  exit 0
fi

if [ -z "$VER" ]; then
  echo "Warning: could not determine the opencode version; installing the 1.x plugin."
fi

mkdir -p "$CFG/plugins"

if [ "$MODE" = "text" ]; then
  write_font "$CFG/plugins/font.json"
  printf '%s' "$TEXT" > "$CFG/plugins/text.txt"
  cat > "$CFG/plugins/no-home-logo.ts" <<'EOF'
import FONT from "./font.json" with { type: "json" }
import * as fs from "node:fs"
import { fileURLToPath } from "node:url"

const TEXT = (() => {
  try {
    const p = fileURLToPath(new URL("./text.txt", import.meta.url))
    const s = fs.readFileSync(p, "utf8").replace(/\r?\n$/, "")
    return s || "opencode"
  } catch { return "opencode" }
})()

const TAG = /<\/?c\d+>/g
const glyph = (ch: string) => (FONT as any).chars[ch.toUpperCase()] || (FONT as any).chars[" "] || [" ", " "]
function artLines(text: string): string[] {
  const n = (FONT as any).lines
  const ls = (FONT as any).letterspace_size
  const lines: string[] = Array.from({ length: n }, () => "")
  for (let i = 0; i < text.length; i++) {
    const g = glyph(text[i])
    for (let row = 0; row < n; row++) lines[row] += (g[row] || "").replace(TAG, "")
    if (i < text.length - 1) for (let row = 0; row < n; row++) lines[row] += " ".repeat(ls)
  }
  return lines
}

export default {
  id: "no-home-logo",
  tui: async (api: any) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    const lines = artLines(TEXT)
    api.slots.register({
      slots: {
        home_logo: () =>
          jsx("box", {
            flexDirection: "column",
            children: lines.map((l) => jsx("text", { content: l, selectable: false })),
          }),
      },
    })
  },
}
EOF
else
  rm -f "$CFG/plugins/font.json" "$CFG/plugins/text.txt"
  cat > "$CFG/plugins/no-home-logo.ts" <<'EOF'
export default {
  id: "no-home-logo",
  tui: async (api) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
  },
}
EOF
fi

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

if [ "$MODE" = "text" ]; then
  echo "Custom text installed. Edit $CFG/plugins/text.txt to change it. Restart opencode to apply."
else
  echo "OpenCode logo removed. Restart opencode to apply."
fi
