# opencode-no-logo installer (Windows)
# Removes the OpenCode wordmark from the TUI home/prompt screen.
#
# opencode 1.x: installs a TUI plugin that takes over the `home_logo` slot.
# opencode 2.x: that slot was removed and the wordmark is drawn inline from
#   bytecode, so instead the installer drops a small TUI plugin that runs inside
#   the renderer and hides the wordmark node in the live render tree. It lives in
#   your config dir, so it keeps working across opencode updates (updates only
#   replace the binary, never your config) — no re-run needed.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
$ErrorActionPreference = "Stop"

$base = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
$cfg = Join-Path $base "opencode"
$plugins = Join-Path $cfg "plugins"
$entry = "./plugins/no-home-logo.ts"
$tuiPath = Join-Path $cfg "tui.json"
$cliPath = Join-Path $cfg "cli.json"
$pkgDir = Join-Path $cfg "no-home-logo"
$utf8 = New-Object System.Text.UTF8Encoding $false

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
  Write-Host "opencode v$ver detected (2.x: installing the renderer plugin)."

  New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null
  $pkgJson = @'
{
  "name": "opencode-no-home-logo",
  "version": "1.0.0",
  "type": "module",
  "exports": { "./tui": "./tui.js" }
}
'@
  $tuiJs = @'
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
  [IO.File]::WriteAllText((Join-Path $pkgDir "package.json"), $pkgJson, $utf8)
  [IO.File]::WriteAllText((Join-Path $pkgDir "tui.js"), $tuiJs, $utf8)

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
    $text = $enc.GetString([System.IO.File]::ReadAllBytes($path))
    if (([regex]::Matches($text, [regex]::Escape('n().height>-1'))).Count -eq 1 -and
        ([regex]::Matches($text, [regex]::Escape('n().height<12'))).Count -eq 0) {
      $idx = $text.IndexOf('n().height>-1')
      $text = $text.Remove($idx, 13).Insert($idx, 'n().height<12')
      [System.IO.File]::WriteAllBytes($path, $enc.GetBytes($text))
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

  Write-Host "OpenCode wordmark removed. Restart opencode to apply."
  Write-Host "This survives opencode updates automatically (it lives in your config)."
  return
}

if (-not $ver) {
  Write-Host "Warning: could not determine the opencode version; installing the 1.x plugin."
}

New-Item -ItemType Directory -Force -Path $plugins | Out-Null

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

Write-Host "OpenCode logo removed. Restart opencode to apply."
