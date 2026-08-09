#!/usr/bin/env python3
"""Parse hl.bind(...) calls out of hyprland.lua into JSON for the cheat sheet.

Usage: parse_keybinds.py [path/to/hyprland.lua]
"""
import json
import os
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/hypr/hyprland.lua")
text = open(path).read()

mod_m = re.search(r'local\s+mod\s*=\s*"([^"]+)"', text)
alt_m = re.search(r'local\s+alt\s*=\s*"([^"]+)"', text)
subs = {"mod": mod_m.group(1) if mod_m else "SUPER", "alt": alt_m.group(1) if alt_m else "ALT"}

BIND_RE = re.compile(r'^\s*hl\.bind\(\s*(.+)$')

# (regex over "the rest of the line" -> description, using \1 etc as needed)
FRIENDLY_RULES = [
    (r'window\.close\(\)', "Close active window"),
    (r'window\.fullscreen\(\)', "Fullscreen"),
    (r'window\.pseudo\(\)', "Toggle pseudotile"),
    (r'layout\("togglesplit"\)', "Toggle split"),
    (r'group\.toggle\(\)', "Toggle window group"),
    (r'window\.cycle_next\(\)', "Cycle windows"),
    (r'workspace\.toggle_special\("magic"\)', "Toggle scratchpad"),
    (r'window\.move\(\{\s*workspace\s*=\s*"special:magic"\s*\}\)', "Move window to scratchpad"),
    (r'window\.move\(\{\s*workspace\s*=\s*\$ws\s*\}\)', "Move window to current workspace"),
    (r'focus\(\{\s*workspace\s*=\s*10\s*\}\)', "Go to workspace 10"),
    (r'window\.move\(\{\s*workspace\s*=\s*10\s*\}\)', "Move window to workspace 10"),
    (r'focus\(\{\s*workspace\s*=\s*"-1"\s*\}\)', "Previous workspace"),
    (r'focus\(\{\s*workspace\s*=\s*"\+1"\s*\}\)', "Next workspace"),
    (r'focus\(\{\s*workspace\s*=\s*"e\+1"\s*\}\)', "Next workspace"),
    (r'focus\(\{\s*workspace\s*=\s*"e-1"\s*\}\)', "Previous workspace"),
    (r'focus\(\{\s*direction\s*=\s*"(\w+)"\s*\}\)', "Move focus {0}"),
    (r'window\.move\(\{\s*direction\s*=\s*"(\w)"\s*\}\)', "Move window {0}"),
    (r"dsp\.exit\(\)", "Exit Hyprland"),
    (r'PowerMenu\.qml', "Power menu"),
    (r'quickshell:hubToggle', "Toggle hub"),
    (r'quickshell:settingsToggle', "Open settings"),
    (r'window\.drag\(\)', "Move window (mouse)"),
    (r'window\.resize\(\)', "Resize window (mouse)"),
    (r'brightnesscontrol\.sh d', "Decrease brightness"),
    (r'brightnesscontrol\.sh i', "Increase brightness"),
    (r'audiocontrol\.sh i', "Volume up"),
    (r'audiocontrol\.sh d', "Volume down"),
    (r'audiocontrol\.sh m', "Mute audio"),
    (r'mediacontrol\.sh', "Play/pause media"),
    (r'screenshot\.sh s', "Screen snip"),
    (r'screenshot\.sh p', "Capture screen"),
    (r'screenshot\.sh sf', "Window capture"),
    (r'screenshot\.sh m', "Capture screen"),
    (r'clipboard\.sh', "Clipboard history"),
    (r'kitty -e btop', "Task manager"),
    (r'hyprpicker', "Color picker"),
    (r'exec_cmd\("([a-zA-Z0-9_./-]+)(?:\s|")', "Launch {0}"),
]


def is_section_header(comment_text):
    """Real section headers here are short labels like "Apps" or "Window
    Actions" -- reject decorative '-- ====' borders and multi-line prose
    notes (which run long and don't look like titles)."""
    t = comment_text.strip()
    if not t or len(t) > 30:
        return False
    if re.fullmatch(r"[=\-\s]+", t):
        return False
    return True
DIR_WORD = {"l": "left", "r": "right", "u": "up", "d": "down"}


def resolve_keys(expr):
    parts = [p.strip() for p in expr.split("..")]
    out = []
    for p in parts:
        p = p.strip()
        if p in subs:
            out.append(subs[p])
        else:
            out.append(p.strip('"'))
    combo = "".join(out)
    return re.sub(r"\s+", " ", combo).strip()


def split_top_level_comma(s):
    """Split on the first comma that isn't inside (), {}, or a string."""
    depth = 0
    in_str = False
    for i, ch in enumerate(s):
        if ch == '"' and (i == 0 or s[i - 1] != "\\"):
            in_str = not in_str
        elif not in_str:
            if ch in "({":
                depth += 1
            elif ch in ")}":
                depth -= 1
            elif ch == "," and depth == 0:
                return s[:i], s[i + 1:]
    return s, ""


def friendly(rest):
    for pattern, template in FRIENDLY_RULES:
        m = re.search(pattern, rest)
        if m:
            groups = [DIR_WORD.get(g, g) for g in m.groups()]
            try:
                return template.format(*groups)
            except (IndexError, KeyError):
                return template
    return None


sections = []
current_section = "Other"
current_binds = []


def flush():
    if current_binds:
        sections.append({"section": current_section, "binds": list(current_binds)})


for line in text.splitlines():
    stripped = line.strip()

    if stripped.startswith("--"):
        comment_text = stripped[2:]
        if is_section_header(comment_text):
            name = comment_text.strip()
            if name != current_section:
                flush()
                current_section = name
                current_binds = []
        continue

    if stripped.startswith("hl.bind") and "tostring(i)" in stripped:
        # The 1..9 workspace-loop binds -- synthesize once, skip the raw lines.
        if not any(b["keys"] == "SUPER + 1..9" for b in current_binds):
            current_binds.append({"keys": "SUPER + 1..9", "desc": "Go to workspace 1-9"})
            current_binds.append({"keys": "SUPER + SHIFT + 1..9", "desc": "Move window to workspace 1-9"})
        continue

    bind_m = BIND_RE.match(line)
    if not bind_m:
        continue

    body = bind_m.group(1)
    comment = ""
    if "-- " in body:
        body, _, comment = body.partition("-- ")
        comment = comment.strip()

    key_expr, rest = split_top_level_comma(body.strip())
    keys = resolve_keys(key_expr)
    if keys.startswith("switch:"):
        # Hardware lid-switch hooks, not a keyboard shortcut -- not useful to search.
        continue
    desc = comment or friendly(rest) or "Custom action"
    current_binds.append({"keys": keys, "desc": desc})

flush()
print(json.dumps(sections, indent=2))
