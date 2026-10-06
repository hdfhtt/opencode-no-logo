# opencode-no-logo

Remove the OpenCode wordmark (the big block-art logo) from the
[opencode](https://opencode.ai) TUI home/prompt screen — or replace it with a
rotating MOTD line (suggestion-chip style, like the ChatGPT/Gemini home screen).

OpenCode has no built-in setting to hide it, so this installs a tiny TUI plugin
that takes over the home logo slot. The installer asks which mode you want:

- **remove** (default) — render an empty element where the logo was.
- **motd** — render a random line from a user-editable `motd.txt`.

## Install

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
```

The installer prompts for the mode. When run through a pipe (no terminal), set
`NOLOGO_MODE` first to skip the prompt:

```sh
NOLOGO_MODE=motd curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
```

```powershell
$env:NOLOGO_MODE = "motd"; irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
```

`NOLOGO_MODE` accepts `remove` or `motd`; anything unset/unrecognized defaults
to `remove`.

Then **restart opencode** — plugins load only at startup.

## What it does

Both installers are idempotent and write to your opencode config directory
(`$XDG_CONFIG_HOME/opencode`, defaulting to `~/.config/opencode`):

1. Create `plugins/no-home-logo.ts`, which takes over the `home_logo` slot. In
   **remove** mode it renders an empty element:

   ```ts
   export default {
     id: "no-home-logo",
     tui: async (api) => {
       const { jsx } = await import("@opentui/solid/jsx-runtime")
       api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
     },
   }
   ```

   In **motd** mode it reads `motd.txt` and renders one random line (in the
   theme's normal text color) on each launch; an empty or missing file falls
   back to the empty element.

2. Merge `tui.json` so the plugin is registered, preserving any existing keys
   and entries:

   ```json
   {
     "$schema": "https://opencode.ai/tui.json",
     "plugin": ["./plugins/no-home-logo.ts"]
   }
   ```

   Registering through a config `plugin` array is required — the TUI does not
   auto-scan the `plugins/` directory the way the server does.

3. In **motd** mode only, create `motd.txt` with a few default lines — but only
   if it does not already exist, so re-running the installer never clobbers your
   edits.

## MOTD

`motd.txt` lives in your opencode config directory (`~/.config/opencode/motd.txt`).
One message per line; blank lines and lines starting with `#` are ignored. A
random remaining line is shown where the logo used to be, re-picked each time
the home screen renders. Edit, add, or delete lines freely — no reinstall
needed, just restart opencode. The defaults look like:

```
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
```

## Uninstall

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/u.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/u.sh | bash
```

Both uninstallers delete `plugins/no-home-logo.ts` and `motd.txt`, and remove the
plugin entry from the `plugin` array in `tui.json` (dropping the `plugin` key if
it was the only entry). Then **restart opencode**. Note this also deletes any
custom lines you added to `motd.txt`.

Or remove manually:

1. Delete `~/.config/opencode/plugins/no-home-logo.ts` and
   `~/.config/opencode/motd.txt`.
2. Remove `"./plugins/no-home-logo.ts"` from the `plugin` array in
   `~/.config/opencode/tui.json` (delete the file if that was its only entry).
3. Restart opencode.

## Notes

- A small blank gap remains where the logo sat — the surrounding spacing is
  fixed in opencode's home layout and cannot be collapsed from a plugin. The
  wordmark itself is gone.
- The `@opentui/solid/jsx-runtime` import is done lazily inside `tui()` on
  purpose: a top-level import breaks the module when opencode also loads it in a
  non-TUI context.
- Verified against opencode `1.18.x`. It relies on the `home_logo` TUI slot and
  the `@opentui/solid` runtime that opencode exposes to plugins; a future
  release could rename these.

## License

MIT
