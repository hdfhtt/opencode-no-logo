# opencode-no-logo

Remove the OpenCode wordmark (the big block-art logo) from the
[opencode](https://opencode.ai) TUI home/prompt screen.

OpenCode has no built-in setting to hide it. How the installer removes it depends
on your opencode version, which it detects automatically:

- **opencode 1.x** — installs a tiny TUI plugin that takes over the `home_logo`
  slot and renders an empty element where the logo was.
- **opencode 2.x** — the 2.x TUI rewrite removed that plugin slot (the wordmark
  is now rendered inline, with no slot, config flag, or dedicated theme color),
  so the installer instead applies a tiny, reversible, length-preserving patch to
  the opencode binary that makes the wordmark never render.

## Install

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
```

Then **restart opencode**.

## Staying removed across opencode updates

opencode updates replace the binary, which brings the wordmark back. How that is
handled depends on your platform:

- **Linux / macOS — automatic.** The installer also drops a small server plugin,
  `plugins/no-logo-sync.ts`, that opencode auto-loads on every launch. It checks
  the running binary and re-applies the patch whenever an update has replaced it.
  Because a running binary cannot rewrite itself in place, the re-patch takes
  effect on the **next** launch — so the first session right after an update
  still shows the logo, then it is gone again. No manual step needed.
- **Windows — re-run the installer** after each opencode update. (A running
  `.exe` cannot be replaced in place on Windows, so the self-healing plugin is
  not installed there.) The installer is idempotent and safe to re-run.

### Scope of the automatic re-patch

The sync plugin only ever patches a binary that **still contains the exact
marker** it targets. In practice that is the opencode 2.x line:

| Transition | Handled automatically? |
|---|---|
| 2.x → later 2.x (marker intact) | ✅ yes (Linux/macOS), re-run installer (Windows) |
| a 2.x build that changed the marker, or a future 3.x | ⚠️ no — safe no-op, the logo simply returns |
| 1.x → 2.x | ❌ no — re-run the installer once; it migrates you to the 2.x patch |

It never guesses: if the marker is missing or not unique, it does nothing (no
corruption, no error).

## What it does

The installer writes to your opencode config directory (`$XDG_CONFIG_HOME/opencode`,
defaulting to `~/.config/opencode`) and/or patches the opencode binary.

### opencode 1.x

1. Create `plugins/no-home-logo.ts`, which takes over the `home_logo` slot and
   renders an empty element:

   ```ts
   export default {
     id: "no-home-logo",
     tui: async (api) => {
       const { jsx } = await import("@opentui/solid/jsx-runtime")
       api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
     },
   }
   ```

2. Merge `tui.json` so the plugin is registered, preserving existing keys and
   entries:

   ```json
   {
     "$schema": "https://opencode.ai/tui.json",
     "plugin": ["./plugins/no-home-logo.ts"]
   }
   ```

   Registering through a config `plugin` array is required — the TUI does not
   auto-scan the `plugins/` directory the way the server does.

### opencode 2.x

The home logo component already renders nothing when the terminal height is below
12 rows. The installer finds the single occurrence of that comparison in the
binary and flips it to an always-true one so the wordmark is never drawn:

```
n().height<12   →   n().height>-1
```

Both sides are the same length, so the edit does not disturb the Bun standalone
executable's layout. On Linux/macOS the installer also writes
`plugins/no-logo-sync.ts` (auto-loaded by opencode's server) to re-apply this
after updates, plus a small `.no-logo-stamp` so it can skip the check when the
binary is unchanged. If an old 1.x plugin is still present, the installer also
removes it (it would only error on 2.x).

## Uninstall

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/u.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/u.sh | bash
```

The uninstaller removes the auto-reapply plugin and its stamp first (so it cannot
re-patch), then reverts the 2.x binary patch (`n().height>-1` → `n().height<12`)
when present, and deletes `plugins/no-home-logo.ts` plus its entry in the
`plugin` array in `tui.json` (dropping the `plugin` key if it was the only one).
Then **restart opencode**.

You can also restore a 2.x install by reinstalling or updating opencode, which
replaces the patched binary with a clean one — but if the sync plugin is still
installed it will re-patch on the next launch, so run the uninstaller to stop
that.

## Notes

- A small blank gap remains where the logo sat — the surrounding spacing is fixed
  in opencode's home layout. The wordmark itself is gone.
- The 2.x patch requires `python3` (Linux/macOS) or Windows PowerShell, both used
  only to do a single in-place byte edit. The binary is not rewritten wholesale.
- Verified against opencode `1.18.x` (plugin) and `2.1.2` (binary patch + sync
  plugin). Both rely on internals opencode does not formally expose, so a future
  release could change them; re-check after major updates.

## License

MIT
