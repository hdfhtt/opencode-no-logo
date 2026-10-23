# opencode-no-logo uninstaller (Windows)
# Restores the OpenCode wordmark.
#   opencode 1.x: removes the TUI plugin it installed.
#   opencode 2.x: removes the renderer plugin and its cli.json registration.
# Also cleans up anything left by older versions of this tool.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/u.ps1 | iex
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

# Remove the 2.x renderer plugin registration from cli.json, and the package.
if (Test-Path $cliPath) {
  $cli = $null
  try { $cli = Get-Content -Raw -Path $cliPath | ConvertFrom-Json } catch { $cli = $null }
  if ($cli -is [pscustomobject] -and $cli.PSObject.Properties.Match('plugins').Count) {
    $kept = @($cli.plugins | Where-Object { $_ -ne $pkgDir })
    if ($kept.Count -gt 0) { $cli.plugins = @($kept) } else { $cli.PSObject.Properties.Remove('plugins') }
    [IO.File]::WriteAllText($cliPath, ($cli | ConvertTo-Json -Depth 20), $utf8)
  }
}
if (Test-Path $pkgDir) { Remove-Item -Recurse -Force $pkgDir }

# Revert an inert binary patch left by older versions (no-op otherwise).
$oc = Get-OpencodeExe
if ($oc) {
  $path = (Resolve-Path -LiteralPath $oc).Path
  $enc = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
  $text = $enc.GetString([System.IO.File]::ReadAllBytes($path))
  if (([regex]::Matches($text, [regex]::Escape('n().height>-1'))).Count -eq 1 -and
      ([regex]::Matches($text, [regex]::Escape('n().height<12'))).Count -eq 0) {
    $idx = $text.IndexOf('n().height>-1')
    $text = $text.Remove($idx, 13).Insert($idx, 'n().height<12')
    [System.IO.File]::WriteAllBytes($path, $enc.GetBytes($text))
    Write-Host "Reverted the opencode binary patch ($path)."
  }
}

# Remove the 1.x plugin, old server sync plugin, stamp, motd, and tui entry.
foreach ($f in @((Join-Path $plugins "no-home-logo.ts"), (Join-Path $plugins "no-logo-sync.ts"), (Join-Path $cfg ".no-logo-stamp"), (Join-Path $cfg "motd.txt"))) {
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

Write-Host "OpenCode logo restored. Restart opencode to apply."
