#!/usr/bin/env sh
# opencode-no-logo installer (Linux/macOS)
# Removes the OpenCode wordmark from the TUI home/prompt screen, or replaces it
# with a rotating MOTD line read from motd.txt.
# Usage: curl -fsSL https://github.com/hdfhtt/opencode-no-logo/raw/main/i.sh | bash
#   Non-interactive: NOLOGO_MODE=remove|motd before the pipe to skip the prompt.
set -e

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
ENTRY="./plugins/no-home-logo.ts"
TUI="$CFG/tui.json"
MOTD="$CFG/motd.txt"

# Resolve mode: env override -> interactive prompt -> default "remove".
# Probe /dev/tty in a subshell first: a redirection failure on `exec` is fatal
# in POSIX sh, but only kills the subshell, so no controlling terminal (CI,
# sandboxes, some pipes) falls through to the default instead of aborting.
MODE="${NOLOGO_MODE:-}"
if [ -z "$MODE" ] && (exec 3<>/dev/tty) 2>/dev/null; then
  b=$(printf '\033[1m'); d=$(printf '\033[2m'); c=$(printf '\033[36m'); r=$(printf '\033[0m')
  {
    printf '\n'
    printf '  %sopencode-no-logo%s\n' "$b" "$r"
    printf '  %sChoose what shows on the opencode home screen.%s\n\n' "$d" "$r"
    printf '    %s1%s  Remove the logo       %s(default)%s\n' "$c" "$r" "$d" "$r"
    printf '    %s2%s  Show a rotating MOTD  %srandom line from motd.txt%s\n\n' "$c" "$r" "$d" "$r"
  } > /dev/tty
  while :; do
    printf '  %sChoice [1/2]:%s ' "$b" "$r" > /dev/tty
    read ans < /dev/tty || { ans=""; break; }
    case "$ans" in
      ""|1|remove) MODE=remove; break ;;
      2|m|motd|MOTD) MODE=motd; break ;;
      *) printf '  %sPlease enter 1 or 2.%s\n' "$d" "$r" > /dev/tty ;;
    esac
  done
fi
[ "$MODE" = "motd" ] || MODE=remove

mkdir -p "$CFG/plugins"

if [ "$MODE" = "motd" ]; then
  cat > "$CFG/plugins/no-home-logo.ts" <<'EOF'
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
EOF
  if [ ! -f "$MOTD" ]; then
    cat > "$MOTD" <<'EOF'
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
EOF
  fi
else
  cat > "$CFG/plugins/no-home-logo.ts" <<'EOF'
export default {
  id: "no-home-logo",
  tui: async (api) => {
    const { jsx } = await import("@opentui/solid/jsx-runtime")
    api.slots.register({ slots: { home_logo: () => jsx("box", {}) } })
  },
}
EOF
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$TUI" "$ENTRY" <<'PY'
import json, os, sys
p, e = sys.argv[1], sys.argv[2]
d = {}
if os.path.exists(p):
    try:
        d = json.load(open(p))
    except Exception:
        d = {}
if not isinstance(d, dict):
    d = {}
d.setdefault("$schema", "https://opencode.ai/tui.json")
pl = d.get("plugin")
if not isinstance(pl, list):
    pl = []
if e not in pl:
    pl.append(e)
d["plugin"] = pl
json.dump(d, open(p, "w"), indent=2)
PY
elif command -v jq >/dev/null 2>&1; then
  [ -f "$TUI" ] || printf '{}' > "$TUI"
  tmp="$(mktemp)"
  jq --arg e "$ENTRY" '(.["$schema"] //= "https://opencode.ai/tui.json") | (.plugin //= []) | (if (.plugin | index($e)) then . else .plugin += [$e] end)' "$TUI" > "$tmp" && mv "$tmp" "$TUI"
elif [ -f "$TUI" ]; then
  echo "tui.json already exists but neither python3 nor jq is available."
  echo "Add \"$ENTRY\" to its \"plugin\" array manually."
else
  printf '{\n  "$schema": "https://opencode.ai/tui.json",\n  "plugin": ["%s"]\n}\n' "$ENTRY" > "$TUI"
fi

if [ "$MODE" = "motd" ]; then
  echo "MOTD enabled. Edit $MOTD to customize. Restart opencode to apply."
else
  echo "OpenCode logo removed. Restart opencode to apply."
fi
