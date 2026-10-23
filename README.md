# opencode-no-logo

Remove the OpenCode wordmark (the big block-art logo) from the
[opencode](https://opencode.ai) TUI home/prompt screen.

OpenCode has no built-in setting to hide it. How the installer removes it depends
on your opencode version, which it detects automatically:

- **opencode 1.x** — installs a tiny TUI plugin that takes over the `home_logo`
  slot and renders an empty element where the logo was.
- **opencode 2.x** — the 2.x TUI rewrite removed that slot. The wordmark is now
  drawn inline (no slot, no config flag, no dedicated theme color) and the TUI
  runs from Bun bytecode, so the binary cannot be patched. Instead the installer
  drops a small **TUI plugin** that runs inside the renderer and hides the
  wordmark node in the live render tree.

## Install

**Windows (PowerShell):**

```powershell
irm https://github.com/hdfhtt/opencode-no-logo/raw/main/i.ps1 | iex
```

**Linux / macOS:**

```sh
curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
```

Then **restart opencode** (fully — close every TUI window; on Linux/macOS a
lingering background service can keep the old screen, so `opencode service
restart` then relaunch).

On **opencode 2.x the removal survives opencode updates automatically** — the
plugin lives in your config directory, which updates never touch. No re-run
needed.

## What it does

The installer writes to your opencode config directory (`$XDG_CONFIG_HOME/opencode`,
defaulting to `~/.config/opencode`).

### opencode 2.x

Creates a small plugin package at `no-home-logo/` and registers it in `cli.json`
under `plugins` (preserving your other settings):

```json
{ "plugins": ["<config>/opencode/no-home-logo"] }
```

The package declares a `./tui` export, so opencode loads it as a TUI plugin. On
each render it walks the live render tree and hides the one element that is a
block of block-art glyphs at least three rows tall whose subtree is nothing but
block art and whitespace — which is the wordmark, and only the wordmark (the
prompt's bottom border is a single row, a work spinner is a lone glyph, and
ordinary UI mixes in letters). Nothing else on screen is touched.

This needs no binary modification, so opencode updates leave it working.

### opencode 1.x

1. Creates `plugins/no-home-logo.ts`, which takes over the `home_logo` slot and
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

2. Merges `tui.json` so the plugin is registered (the TUI does not auto-scan the
   `plugins/` directory the way the server does):

   ```json
   { "$schema": "https://opencode.ai/tui.json", "plugin": ["./plugins/no-home-logo.ts"] }
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

The uninstaller removes the 2.x renderer plugin and its `cli.json` entry (and the
1.x plugin and its `tui.json` entry), then restores the wordmark. It also cleans
up anything left by older versions of this tool (an inert binary patch, a server
sync plugin, and its stamp). Then **restart opencode**.

## Notes

- A small blank gap remains where the logo sat — the surrounding spacing is fixed
  in opencode's home layout. The wordmark itself is gone.
- Verified against opencode `1.18.x` (slot plugin) and `2.1.2` (renderer plugin).
  Both rely on internals opencode does not formally expose, so a future release
  could change them. The 2.x plugin degrades safely: if the render tree changes
  it simply hides nothing (the logo reappears) rather than breaking the UI.

## License

MIT
