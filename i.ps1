# opencode-no-logo installer (Windows)
# Removes the OpenCode wordmark from the TUI home/prompt screen.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
$ErrorActionPreference = "Stop"

$base = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
$cfg = Join-Path $base "opencode"
$plugins = Join-Path $cfg "plugins"
$entry = "./plugins/no-home-logo.ts"
$tuiPath = Join-Path $cfg "tui.json"

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

$utf8 = New-Object System.Text.UTF8Encoding $false
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

$json = $tui | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($tuiPath, $json, $utf8)

Write-Host "OpenCode logo removed. Restart opencode to apply."
