#!/usr/bin/env python3
"""hpo zhen force - set a game to use GE-Proton via Steam config.vdf"""
import sys, os, re, shutil, subprocess

PROTON = "GE-Proton10-34"

def find_config():
    candidates = [
        "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/config/config.vdf",
        "~/.local/share/Steam/config/config.vdf",
        "~/.steam/steam/config/config.vdf",
        "~/.steam/debian-installation/config/config.vdf",
    ]
    for c in candidates:
        p = os.path.expanduser(c)
        if os.path.exists(p):
            return p
    return None

def steam_running():
    try:
        out = subprocess.run(["pgrep", "-x", "steam"], capture_output=True)
        return out.returncode == 0
    except Exception:
        return False

def main():
    if len(sys.argv) < 2:
        print("[ZHEN] Usage: zhen-force.py <appid>", file=sys.stderr)
        sys.exit(1)
    appid = sys.argv[1].strip()
    if not appid.isdigit():
        print(f"[ZHEN] Invalid AppID: {appid}", file=sys.stderr)
        sys.exit(1)

    if steam_running():
        print("[ZHEN] Steam is running! Close Steam first, then try again.", file=sys.stderr)
        print("       (Steam overwrites config.vdf on exit.)", file=sys.stderr)
        sys.exit(3)

    cfg = find_config()
    if not cfg:
        print("[ZHEN] Could not find Steam config.vdf", file=sys.stderr)
        sys.exit(2)

    with open(cfg, "r", encoding="utf-8") as f:
        content = f.read()

    # Backup
    shutil.copy(cfg, cfg + ".hpo-bak")

    entry = (
        '\t\t\t\t\t"%s"\n'
        '\t\t\t\t\t{\n'
        '\t\t\t\t\t\t"name"\t\t"%s"\n'
        '\t\t\t\t\t\t"config"\t\t""\n'
        '\t\t\t\t\t\t"priority"\t\t"250"\n'
        '\t\t\t\t\t}\n'
    ) % (appid, PROTON)

    m = re.search(r'("CompatToolMapping"\s*\{)', content)
    if not m:
        print("[ZHEN] No CompatToolMapping block found in config.vdf", file=sys.stderr)
        sys.exit(2)

    # If appid already mapped, replace its block; else insert after the opening brace
    existing = re.search(r'\t*"%s"\s*\{[^}]*\}\n' % re.escape(appid), content)
    if existing:
        content = content[:existing.start()] + entry + content[existing.end():]
        action = "updated"
    else:
        insert_at = m.end()
        content = content[:insert_at] + "\n" + entry + content[insert_at:]
        action = "added"

    with open(cfg, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"[ZHEN] {action} GE-Proton mapping for AppID {appid}")
    print(f"       Tool: {PROTON}")
    print(f"       Backup saved: {os.path.basename(cfg)}.hpo-bak")

if __name__ == "__main__":
    main()
