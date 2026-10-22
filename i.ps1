# opencode-no-logo installer (Windows)
# Removes the OpenCode wordmark from the TUI home/prompt screen.
#
# opencode 1.x: installs a TUI plugin that takes over the `home_logo` slot.
# opencode 2.x: that slot was removed, so instead the installer applies a tiny,
#   reversible, length-preserving patch to the opencode binary that makes the
#   home wordmark never render. Re-run after updating opencode (updates replace
#   the binary).
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
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

$oc = Get-OpencodeExe
$ver = $null
if ($oc) {
  try { $out = (& $oc --version 2>$null) -join "`n" } catch { $out = "" }
  $m = [regex]::Match($out, '\d+\.\d+\.\d+')
  if ($m.Success) { $ver = $m.Value }
}
$major = if ($ver) { [int]($ver.Split('.')[0]) } else { $null }

if ($null -ne $major -and $major -ge 2) {
  Write-Host "opencode v$ver detected (2.x: patching the binary)."
  $path = (Resolve-Path -LiteralPath $oc).Path

  # The home logo renders nothing when height<12; flipping the comparison to the
  # always-true ">-1" hides it at every size. Same byte length, so the Bun
  # standalone layout stays valid. Latin1 is a 1:1 byte<->char round-trip.
  $enc = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
  $text = $enc.GetString([System.IO.File]::ReadAllBytes($path))
  $old = 'n().height<12'
  $new = 'n().height>-1'
  $no = ([regex]::Matches($text, [regex]::Escape($old))).Count
  $nn = ([regex]::Matches($text, [regex]::Escape($new))).Count
  if ($no -eq 1) {
    $idx = $text.IndexOf($old)
    $text = $text.Remove($idx, $old.Length).Insert($idx, $new)
    [System.IO.File]::WriteAllBytes($path, $enc.GetBytes($text))
    Write-Host "Removed the opencode home wordmark ($path)."
  }
  elseif ($no -eq 0 -and $nn -ge 1) {
    Write-Host "opencode is already patched."
  }
  else {
    Write-Error "opencode-no-logo: expected one patch marker, found $no; this opencode build differs from the supported 2.x layout. Not patching."
    exit 1
  }

  # Remove any plugin left by an earlier 1.x install; on 2.x it only errors.
  $pluginFile = Join-Path $plugins "no-home-logo.ts"
  if (Test-Path $pluginFile) {
    Remove-Item -Force $pluginFile
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
    Write-Host "Removed a leftover v1 plugin; its startup error will stop."
  }

  Write-Host "Restart opencode to apply. Re-run this installer after updating opencode."
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
