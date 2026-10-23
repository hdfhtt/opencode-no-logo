# opencode-no-logo

Remove the OpenCode wordmark (the big block-art logo) from the
[opencode](https://opencode.ai) TUI home/prompt screen — or **replace it with
custom text** of your own.

When you run the installer it asks what you want on the home screen:

```
  1  Remove the logo    (default)
  2  Show custom text   your own word or phrase
```

Pick **2** and it prompts for the text to display, which it draws in the same
compact half-block font opencode uses for its own wordmark (full A–Z/0–9, upper
or lower case). To skip the prompt (e.g. in a script), set `NOLOGO_MODE=remove`
or `NOLOGO_MODE=text` (with `NOLOGO_TEXT="your words"`) before running.

OpenCode has no built-in setting for any of this. How the installer applies the
change depends on your opencode version, which it detects automatically:

- **opencode 1.x** — installs a tiny TUI plugin that takes over the `home_logo`
  slot and renders either an empty element or your custom text where the logo was.
- **opencode 2.x** — the 2.x TUI rewrite removed that slot. The wordmark is now
  drawn inline (no slot, no config flag, no dedicated theme color) and the TUI
  runs from Bun bytecode, so the binary cannot be patched. Instead the installer
  drops a small **TUI plugin** that runs inside the renderer and hides (or
  rewrites) the wordmark node in the live render tree.

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
each render it walks the live render tree and finds the one element that is a
block of block-art glyphs at least three rows tall whose subtree is nothing but
block art and whitespace — which is the wordmark, and only the wordmark (the
prompt's bottom border is a single row, a work spinner is a lone glyph, and
ordinary UI mixes in letters). Nothing else on screen is touched.

For **remove** mode it hides that node. For **custom text** mode it hides the
node and paints your text in its place, drawn from a bundled copy of the cfonts
`tiny` font (`font.json`) with the phrase read from `text.txt` — so you can edit
`text.txt` later to change it without re-running. The text uses the theme's
foreground color and is suppressed while the Ctrl+P palette or a dialog is open
(a z-index check), so it never stamps over overlays.

This needs no binary modification, so opencode updates leave it working.

### opencode 1.x

1. Creates `plugins/no-home-logo.ts`, which takes over the `home_logo` slot and
   renders an empty element (remove mode):

   ```ts
   export default {
     id: "no-home-logo",
     tui: async (api) => {
       const { jsx } = await import("@opentui/solid/jsx-runtime")
       api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
     },
   }
   ```

   In custom-text mode it instead renders your phrase (from `plugins/text.txt`,
   in the `plugins/font.json` block font) into the slot.

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
1.x plugin and its `tui.json` entry, including any `font.json`/`text.txt` from
custom-text mode), then restores the wordmark. It also cleans up anything left by
older versions of this tool (an inert binary patch, a server sync plugin, and its
stamp). Then **restart opencode**.

## Notes

- In **remove** mode a small blank gap remains where the logo sat — the
  surrounding spacing is fixed in opencode's home layout. The wordmark itself is
  gone. In **custom text** mode your text is centered in that same space.
- Verified against opencode `2.1.3` (renderer plugin, remove and custom text).
  The slot plugin path targets opencode `1.x`. Both rely on internals opencode
  does not formally expose, so a future release could change them. The 2.x plugin
  degrades safely: if the render tree changes it simply does nothing (the logo
  reappears) rather than breaking the UI.

## License

MIT
