# opencode-no-logo installer (Windows)
# Removes the OpenCode wordmark from the TUI home/prompt screen, or replaces it
# with custom text of your choosing.
#
# opencode 1.x: installs a TUI plugin that takes over the `home_logo` slot.
# opencode 2.x: that slot was removed and the wordmark is drawn inline from
#   bytecode, so instead the installer drops a small TUI plugin that runs inside
#   the renderer and rewrites the wordmark node in the live render tree. It lives
#   in your config dir, so it keeps working across opencode updates (updates only
#   replace the binary, never your config) — no re-run needed.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
#   Non-interactive: set $env:NOLOGO_MODE = "remove"|"text" to skip the prompt,
#   and $env:NOLOGO_TEXT = "your words" to supply the custom text.
$ErrorActionPreference = "Stop"

$base = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
$cfg = Join-Path $base "opencode"
$plugins = Join-Path $cfg "plugins"
$entry = "./plugins/no-home-logo.ts"
$tuiPath = Join-Path $cfg "tui.json"
$cliPath = Join-Path $cfg "cli.json"
$pkgDir = Join-Path $cfg "no-home-logo"
$utf8 = New-Object System.Text.UTF8Encoding $false

# The cfonts "tiny" font (full A-Z/0-9), used to draw custom text in the same
# compact half-block style as opencode's own wordmark.
$fontJson = @'
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
'@

# Resolve mode: env override -> interactive prompt -> default "remove".
$mode = $env:NOLOGO_MODE
$text = $env:NOLOGO_TEXT
if (-not $mode) {
  Write-Host ""
  Write-Host "  opencode-no-logo"
  Write-Host "  Choose what shows on the opencode home screen."
  Write-Host ""
  Write-Host "    1  Remove the logo    (default)"
  Write-Host "    2  Show custom text   your own word or phrase"
  Write-Host ""
  while ($true) {
    $ans = Read-Host "  Choice [1/2]"
    if ($ans -eq "" -or $ans -eq "1" -or $ans -eq "remove") { $mode = "remove"; break }
    elseif ($ans -eq "2" -or $ans -eq "text") { $mode = "text"; break }
    else { Write-Host "  Please enter 1 or 2." }
  }
}
if ($mode -ne "text") { $mode = "remove" }
if ($mode -eq "text" -and -not $text) {
  while (-not $text) { $text = Read-Host "  Enter the text to display" }
}
if ($mode -eq "text" -and -not $text) { $text = "opencode" }

# The custom-text renderer plugin (opencode 2.x). Paints the chosen text in
# cfonts' "tiny" font where the wordmark sat, with a z-index overlay guard.
$tuiJsText = @'
// opencode-no-logo — replace the opencode home wordmark with custom text on 2.x.
//
// On 2.x the wordmark is rendered inline: no plugin slot, no config flag, no
// dedicated theme color, and the TUI runs from Bun bytecode so the binary's
// source cannot be patched. A TUI plugin runs inside the renderer process, so
// this finds the wordmark in the live render tree, hides it, and paints custom
// text in its place using cfonts' "tiny" font — the same compact half-block
// style as opencode's own wordmark — into the composited frame buffer, centred
// where the wordmark sat. A z-index guard skips painting whenever an overlay
// (Ctrl+P palette, a dialog) covers the home screen.

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
const NON_ART = /[^▀-▟\s]/

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
    if (!r || !r.root) return

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
      let blocks = (t.match(/[▀-▟]/g) || []).length
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
'@

# The hide-only renderer plugin (opencode 2.x).
$tuiJsRemove = @'
// opencode-no-logo — hide the opencode home wordmark on opencode 2.x.
//
// On 2.x the wordmark is rendered inline: no plugin slot, no config flag, no
// dedicated theme color, and the TUI runs from Bun bytecode so the binary's
// source cannot be patched. A TUI plugin, however, runs inside the renderer
// process, so this hides the wordmark in the live render tree. A frame callback
// sets the node's visible=false (overlay-safe, layout-correct); a post-process
// pass clears its cells in the composited buffer only on the one frame it is
// painted before being hidden, which removes the launch flash without ever
// stamping over the Ctrl+P palette or dialogs.

const NON_ART = /[^▀-▟\s]/

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
    if (!r || !r.root) return

    const analyze = (node) => {
      const t = textOf(node)
      let art = !NON_ART.test(t)
      let blocks = (t.match(/[▀-▟]/g) || []).length
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
'@

function Get-OpencodeExe {
  $c = Get-Command opencode -ErrorAction SilentlyContinue
  if ($c -and $c.Source) { return $c.Source }
  foreach ($p in @((Join-Path $HOME ".opencode\bin\opencode.exe"), (Join-Path $HOME ".opencode\bin\opencode"))) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

$oc = Get-OpencodeExe
$ver = $null
if ($oc) {
  try { $out = (& $oc --version 2>$null) -join "`n" } catch { $out = "" }
  $m = [regex]::Match($out, '\d+\.\d+\.\d+')
  if ($m.Success) { $ver = $m.Value }
}
$major = if ($ver) { [int]($ver.Split('.')[0]) } else { $null }

if ($null -ne $major -and $major -ge 2) {
  if ($mode -eq "text") {
    Write-Host "opencode v$ver detected (2.x: installing the renderer plugin, custom text)."
  } else {
    Write-Host "opencode v$ver detected (2.x: installing the renderer plugin)."
  }

  New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null
  $pkgJson = @'
{
  "name": "opencode-no-home-logo",
  "version": "1.0.0",
  "type": "module",
  "exports": { "./tui": "./tui.js" }
}
'@
  [IO.File]::WriteAllText((Join-Path $pkgDir "package.json"), $pkgJson, $utf8)

  if ($mode -eq "text") {
    [IO.File]::WriteAllText((Join-Path $pkgDir "font.json"), $fontJson, $utf8)
    [IO.File]::WriteAllText((Join-Path $pkgDir "text.txt"), $text, $utf8)
    [IO.File]::WriteAllText((Join-Path $pkgDir "tui.js"), $tuiJsText, $utf8)
  } else {
    foreach ($f in @((Join-Path $pkgDir "font.json"), (Join-Path $pkgDir "text.txt"))) {
      if (Test-Path $f) { Remove-Item -Force $f }
    }
    [IO.File]::WriteAllText((Join-Path $pkgDir "tui.js"), $tuiJsRemove, $utf8)
  }

  # Register the plugin in cli.json (merge; preserve everything else).
  $cli = $null
  if (Test-Path $cliPath) { try { $cli = Get-Content -Raw -Path $cliPath | ConvertFrom-Json } catch { $cli = $null } }
  if ($null -eq $cli -or $cli -isnot [pscustomobject]) { $cli = [pscustomobject]@{} }
  if (-not $cli.PSObject.Properties.Match('$schema').Count) {
    $cli | Add-Member -NotePropertyName '$schema' -NotePropertyValue "https://opencode.ai/v2/cli.json"
  }
  $list = @()
  if ($cli.PSObject.Properties.Match('plugins').Count -and $cli.plugins) { $list = @($cli.plugins) }
  if ($list -notcontains $pkgDir) { $list += $pkgDir }
  if ($cli.PSObject.Properties.Match('plugins').Count) { $cli.plugins = @($list) }
  else { $cli | Add-Member -NotePropertyName 'plugins' -NotePropertyValue @($list) }
  [IO.File]::WriteAllText($cliPath, ($cli | ConvertTo-Json -Depth 20), $utf8)

  # Clean up anything left by older versions: revert an inert binary patch,
  # remove the old server sync plugin, its stamp, and any stale v1 plugin.
  if ($oc) {
    $path = (Resolve-Path -LiteralPath $oc).Path
    $enc = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
    $text2 = $enc.GetString([System.IO.File]::ReadAllBytes($path))
    if (([regex]::Matches($text2, [regex]::Escape('n().height>-1'))).Count -eq 1 -and
        ([regex]::Matches($text2, [regex]::Escape('n().height<12'))).Count -eq 0) {
      $idx = $text2.IndexOf('n().height>-1')
      $text2 = $text2.Remove($idx, 13).Insert($idx, 'n().height<12')
      [System.IO.File]::WriteAllBytes($path, $enc.GetBytes($text2))
      Write-Host "Reverted a leftover (inert) binary patch."
    }
  }
  foreach ($f in @((Join-Path $plugins "no-logo-sync.ts"), (Join-Path $cfg ".no-logo-stamp"), (Join-Path $plugins "no-home-logo.ts"))) {
    if (Test-Path $f) { Remove-Item -Force $f }
  }
  if (Test-Path $tuiPath) {
    $tui = $null
    try { $tui = Get-Content -Raw -Path $tuiPath | ConvertFrom-Json } catch { $tui = $null }
    if ($tui -is [pscustomobject] -and $tui.PSObject.Properties.Match('plugin').Count) {
      $kept = @($tui.plugin | Where-Object { $_ -ne $entry })
      if ($kept.Count -gt 0) { $tui.plugin = @($kept) } else { $tui.PSObject.Properties.Remove('plugin') }
      [IO.File]::WriteAllText($tuiPath, ($tui | ConvertTo-Json -Depth 20), $utf8)
    }
  }

  if ($mode -eq "text") {
    Write-Host "Custom text installed. Edit $(Join-Path $pkgDir 'text.txt') to change it. Restart opencode to apply."
  } else {
    Write-Host "OpenCode wordmark removed. Restart opencode to apply."
  }
  Write-Host "This survives opencode updates automatically (it lives in your config)."
  return
}

if (-not $ver) {
  Write-Host "Warning: could not determine the opencode version; installing the 1.x plugin."
}

New-Item -ItemType Directory -Force -Path $plugins | Out-Null

if ($mode -eq "text") {
  [IO.File]::WriteAllText((Join-Path $plugins "font.json"), $fontJson, $utf8)
  [IO.File]::WriteAllText((Join-Path $plugins "text.txt"), $text, $utf8)
  $plugin = @'
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
const glyph = (ch) => FONT.chars[ch.toUpperCase()] || FONT.chars[" "] || [" ", " "]
function artLines(text) {
  const n = FONT.lines
  const ls = FONT.letterspace_size
  const lines = Array.from({ length: n }, () => "")
  for (let i = 0; i < text.length; i++) {
    const g = glyph(text[i])
    for (let row = 0; row < n; row++) lines[row] += (g[row] || "").replace(TAG, "")
    if (i < text.length - 1) for (let row = 0; row < n; row++) lines[row] += " ".repeat(ls)
  }
  return lines
}

export default {
  id: "no-home-logo",
  tui: async (api) => {
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
'@
  [IO.File]::WriteAllText((Join-Path $plugins "no-home-logo.ts"), $plugin, $utf8)
} else {
  foreach ($f in @((Join-Path $plugins "font.json"), (Join-Path $plugins "text.txt"))) {
    if (Test-Path $f) { Remove-Item -Force $f }
  }
  $plugin = @'
export default {
  id: "no-home-logo",
  tui: async (api) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
  },
}
'@
  [IO.File]::WriteAllText((Join-Path $plugins "no-home-logo.ts"), $plugin, $utf8)
}

$tui = $null
if (Test-Path $tuiPath) {
  try { $tui = Get-Content -Raw -Path $tuiPath | ConvertFrom-Json } catch { $tui = $null }
}
if ($null -eq $tui -or $tui -isnot [pscustomobject]) { $tui = [pscustomobject]@{} }

if (-not $tui.PSObject.Properties.Match('$schema').Count) {
  $tui | Add-Member -NotePropertyName '$schema' -NotePropertyValue "https://opencode.ai/tui.json"
}

$list = @()
if ($tui.PSObject.Properties.Match('plugin').Count -and $tui.plugin) { $list = @($tui.plugin) }
if ($list -notcontains $entry) { $list += $entry }
if ($tui.PSObject.Properties.Match('plugin').Count) { $tui.plugin = @($list) }
else { $tui | Add-Member -NotePropertyName 'plugin' -NotePropertyValue @($list) }

[IO.File]::WriteAllText($tuiPath, ($tui | ConvertTo-Json -Depth 20), $utf8)

if ($mode -eq "text") {
  Write-Host "Custom text installed. Edit $(Join-Path $plugins 'text.txt') to change it. Restart opencode to apply."
} else {
  Write-Host "OpenCode logo removed. Restart opencode to apply."
}
