# opencode-no-logo uninstaller (Windows)
# Restores the OpenCode wordmark by removing the plugin it installed.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/u.ps1 | iex
$ErrorActionPreference = "Stop"

$base = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
$cfg = Join-Path $base "opencode"
$plugins = Join-Path $cfg "plugins"
$entry = "./plugins/no-home-logo.ts"
$tuiPath = Join-Path $cfg "tui.json"

$pluginFile = Join-Path $plugins "no-home-logo.ts"
if (Test-Path $pluginFile) { Remove-Item -Force $pluginFile }

if (-not (Test-Path $tuiPath)) {
  Write-Host "OpenCode logo restored. Restart opencode to apply."
  return
}

$utf8 = New-Object System.Text.UTF8Encoding $false

$tui = $null
try { $tui = Get-Content -Raw -Path $tuiPath | ConvertFrom-Json } catch { $tui = $null }

if ($tui -is [pscustomobject] -and $tui.PSObject.Properties.Match('plugin').Count) {
  $list = @($tui.plugin | Where-Object { $_ -ne $entry })
  if ($list.Count -gt 0) { $tui.plugin = @($list) }
  else { $tui.PSObject.Properties.Remove('plugin') }

  $json = $tui | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($tuiPath, $json, $utf8)
}

Write-Host "OpenCode logo restored. Restart opencode to apply."
