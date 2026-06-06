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
    arg = sys.argv[1].strip()

    if steam_running():
        print("[ZHEN] Steam is running! Close Steam first, then try again.", file=sys.stderr)
        print("       (Steam overwrites config.vdf on exit.)", file=sys.stderr)
        sys.exit(3)

    # Build list of appids to set
    appids = []
    if arg == "--all":
        alias_file = os.path.expanduser("~/.config/hpo/steam_aliases.txt")
        if not os.path.exists(alias_file):
            print("[ZHEN] No steam_aliases.txt found", file=sys.stderr)
            sys.exit(2)
        with open(alias_file) as af:
            for line in af:
                line = line.strip()
                if not line or "=" not in line:
                    continue
                _, val = line.split("=", 1)
                val = val.strip()
                if val.isdigit():
                    appids.append(val)
    else:
        if not arg.isdigit():
            print(f"[ZHEN] Invalid AppID: {arg}", file=sys.stderr)
            sys.exit(1)
        appids = [arg]

    cfg = find_config()
    if not cfg:
        print("[ZHEN] Could not find Steam config.vdf", file=sys.stderr)
        sys.exit(2)

    with open(cfg, "r", encoding="utf-8") as f:
        content = f.read()

    # Backup
    shutil.copy(cfg, cfg + ".hpo-bak")

    m = re.search(r'("CompatToolMapping"\s*\{)', content)
    if not m:
        print("[ZHEN] No CompatToolMapping block found in config.vdf", file=sys.stderr)
        sys.exit(2)

    count = 0
    for appid in appids:
        entry = (
            '\t\t\t\t\t"%s"\n'
            '\t\t\t\t\t{\n'
            '\t\t\t\t\t\t"name"\t\t"%s"\n'
            '\t\t\t\t\t\t"config"\t\t""\n'
            '\t\t\t\t\t\t"priority"\t\t"250"\n'
            '\t\t\t\t\t}\n'
        ) % (appid, PROTON)

        existing = re.search(r'\t*"%s"\s*\{[^}]*\}\n' % re.escape(appid), content)
        if existing:
            content = content[:existing.start()] + entry + content[existing.end():]
        else:
            insert_at = m.end()
            content = content[:insert_at] + "\n" + entry + content[insert_at:]
        count += 1
        print(f"[ZHEN] set GE-Proton for AppID {appid}")

    with open(cfg, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"[ZHEN] Done! {count} game(s) now use {PROTON}")
    print(f"       Backup saved: {os.path.basename(cfg)}.hpo-bak")

if __name__ == "__main__":
    main()
