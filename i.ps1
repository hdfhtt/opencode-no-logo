# opencode-no-logo installer (Windows)
# Removes the OpenCode wordmark from the TUI home/prompt screen, or replaces it
# with a rotating MOTD line read from motd.txt.
# Usage: irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
#   Non-interactive: $env:NOLOGO_MODE = "remove"|"motd" to skip the prompt.
$ErrorActionPreference = "Stop"

$base = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ".config" }
$cfg = Join-Path $base "opencode"
$plugins = Join-Path $cfg "plugins"
$entry = "./plugins/no-home-logo.ts"
$tuiPath = Join-Path $cfg "tui.json"
$motdPath = Join-Path $cfg "motd.txt"

# Resolve mode: env override -> interactive prompt -> default "remove".
$mode = $env:NOLOGO_MODE
if (-not $mode -and [Environment]::UserInteractive) {
  Write-Host ""
  Write-Host "  opencode-no-logo" -ForegroundColor White
  Write-Host "  Choose what shows on the opencode home screen." -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "    " -NoNewline; Write-Host "1" -ForegroundColor Cyan -NoNewline
  Write-Host "  Remove the logo       " -NoNewline; Write-Host "(default)" -ForegroundColor DarkGray
  Write-Host "    " -NoNewline; Write-Host "2" -ForegroundColor Cyan -NoNewline
  Write-Host "  Show a rotating MOTD  " -NoNewline; Write-Host "random line from motd.txt" -ForegroundColor DarkGray
  Write-Host ""
  do {
    $ans = Read-Host "  Choice [1/2] (default 1)"
    if ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^(1|remove)$') { $mode = "remove"; break }
    if ($ans -match '^(2|m|motd)$') { $mode = "motd"; break }
    Write-Host "  Please enter 1 or 2." -ForegroundColor Yellow
  } while ($true)
}
if ($mode -ne "motd") { $mode = "remove" }

New-Item -ItemType Directory -Force -Path $plugins | Out-Null

$utf8 = New-Object System.Text.UTF8Encoding $false

if ($mode -eq "motd") {
  $plugin = @'
export default {
  id: "no-home-logo",
  tui: async (api) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    const fs = await import("node:fs")
    const os = await import("node:os")
    const base = process.env.XDG_CONFIG_HOME || `${os.homedir()}/.config`
    const file = `${base}/opencode/motd.txt`
    const pick = () => {
      try {
        const lines = fs.readFileSync(file, "utf8").split("\n")
          .map((l) => l.trim())
          .filter((l) => l && !l.startsWith("#"))
        return lines.length ? lines[Math.floor(Math.random() * lines.length)] : ""
      } catch {
        return ""
      }
    }
    api.slots.register({
      slots: {
        home_logo: (_p, ctx) => {
          const msg = pick()
          return msg
            ? jsx("text", { fg: ctx?.theme?.current?.text, selectable: false, children: msg })
            : jsx("box", {})
        },
      },
    })
  },
}
'@

  $motd = @'
# opencode MOTD — one message per line; '#' lines are ignored.
# A random line appears where the logo used to be. Edit or delete freely.
Explain this codebase
Find and fix a bug in a function
Write tests for the current file
Refactor a module to be more readable
Add a new feature end to end
Review recent changes before a commit
Explain an error and suggest a fix
Plan out a large refactor
'@
  if (-not (Test-Path $motdPath)) {
    [IO.File]::WriteAllText($motdPath, $motd, $utf8)
  }
}
else {
  $plugin = @'
export default {
  id: "no-home-logo",
  tui: async (api) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
  },
}
'@
}

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

if ($mode -eq "motd") {
  Write-Host "MOTD enabled. Edit $motdPath to customize. Restart opencode to apply."
}
else {
  Write-Host "OpenCode logo removed. Restart opencode to apply."
}
