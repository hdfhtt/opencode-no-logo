# opencode-no-logo uninstaller (Windows)
# Restores the OpenCode wordmark.
#   opencode 1.x: removes the plugin it installed.
#   opencode 2.x: reverts the binary patch.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/u.ps1 | iex
$ErrorActionPreference = "Stop"

$base = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
$cfg = Join-Path $base "opencode"
$plugins = Join-Path $cfg "plugins"
$entry = "./plugins/no-home-logo.ts"
$tuiPath = Join-Path $cfg "tui.json"
$utf8 = New-Object System.Text.UTF8Encoding $false

function Get-OpencodeExe {
  $c = Get-Command opencode -ErrorAction SilentlyContinue
  if ($c -and $c.Source) { return $c.Source }
  foreach ($p in @((Join-Path $HOME ".opencode\bin\opencode.exe"), (Join-Path $HOME ".opencode\bin\opencode"))) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

# Revert the binary patch if present (no-op otherwise).
$oc = Get-OpencodeExe
if ($oc) {
  $path = (Resolve-Path -LiteralPath $oc).Path
  $enc = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
  $text = $enc.GetString([System.IO.File]::ReadAllBytes($path))
  $patched = 'n().height>-1'
  $orig = 'n().height<12'
  if (([regex]::Matches($text, [regex]::Escape($patched))).Count -eq 1 -and
      ([regex]::Matches($text, [regex]::Escape($orig))).Count -eq 0) {
    $idx = $text.IndexOf($patched)
    $text = $text.Remove($idx, $patched.Length).Insert($idx, $orig)
    [System.IO.File]::WriteAllBytes($path, $enc.GetBytes($text))
    Write-Host "Reverted the opencode binary patch ($path)."
  }
}

# Remove the auto-reapply plugin and its stamp (if a shared config carried them).
$syncFile = Join-Path $plugins "no-logo-sync.ts"
if (Test-Path $syncFile) { Remove-Item -Force $syncFile }
$stampFile = Join-Path $cfg ".no-logo-stamp"
if (Test-Path $stampFile) { Remove-Item -Force $stampFile }

# Remove the 1.x plugin, its tui.json entry, and any leftover motd.txt.
$pluginFile = Join-Path $plugins "no-home-logo.ts"
if (Test-Path $pluginFile) { Remove-Item -Force $pluginFile }

$motdFile = Join-Path $cfg "motd.txt"
if (Test-Path $motdFile) { Remove-Item -Force $motdFile }

if (Test-Path $tuiPath) {
  $tui = $null
  try { $tui = Get-Content -Raw -Path $tuiPath | ConvertFrom-Json } catch { $tui = $null }
  if ($tui -is [pscustomobject] -and $tui.PSObject.Properties.Match('plugin').Count) {
    $list = @($tui.plugin | Where-Object { $_ -ne $entry })
    if ($list.Count -gt 0) { $tui.plugin = @($list) }
    else { $tui.PSObject.Properties.Remove('plugin') }
    [IO.File]::WriteAllText($tuiPath, ($tui | ConvertTo-Json -Depth 20), $utf8)
  }
}

Write-Host "OpenCode logo restored. Restart opencode to apply."
