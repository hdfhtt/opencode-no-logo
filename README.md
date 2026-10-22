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

> **opencode 2.x:** opencode updates replace the binary, so **re-run the
> installer after each update**. The installer is idempotent and safe to re-run.

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
executable's layout. If an old 1.x plugin is still present, the installer also
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

The uninstaller reverts the 2.x binary patch (`n().height>-1` → `n().height<12`)
when present, and deletes `plugins/no-home-logo.ts` plus its entry in the
`plugin` array in `tui.json` (dropping the `plugin` key if it was the only one).
Then **restart opencode**.

You can also restore a 2.x install by reinstalling or updating opencode, which
replaces the patched binary with a clean one.

## Notes

- A small blank gap remains where the logo sat — the surrounding spacing is fixed
  in opencode's home layout. The wordmark itself is gone.
- The 2.x patch requires `python3` (Linux/macOS) or Windows PowerShell, both used
  only to do a single in-place byte edit. The binary is not rewritten wholesale.
- Verified against opencode `1.18.x` (plugin) and `2.1.2` (binary patch). Both
  rely on internals opencode does not formally expose, so a future release could
  change them; re-check after major updates.

## License

MIT
