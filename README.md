# opencode-no-logo

Remove the OpenCode wordmark (the big block-art logo) from the
[opencode](https://opencode.ai) TUI home/prompt screen.

OpenCode has no built-in setting to hide it, so this installs a tiny TUI plugin
that replaces the home logo slot with an empty element.

## Install

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
```

Then **restart opencode** — plugins load only at startup.

## What it does

Both installers are idempotent and write to your opencode config directory
(`$XDG_CONFIG_HOME/opencode`, defaulting to `~/.config/opencode`):

1. Create `plugins/no-home-logo.ts` — the plugin:

   ```ts
   export default {
     id: "no-home-logo",
     tui: async (api) => {
       const { jsx } = await import("@opentui/solid/jsx-runtime")
       api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
     },
   }
   ```

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

## Uninstall

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/u.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/u.sh | bash
```

Both uninstallers delete `plugins/no-home-logo.ts` and remove its entry from the
`plugin` array in `tui.json` (dropping the `plugin` key if it was the only
entry). Then **restart opencode**.

Or remove manually:

1. Delete `~/.config/opencode/plugins/no-home-logo.ts`.
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
