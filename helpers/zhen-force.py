#!/usr/bin/env python3
"""hpo zhen force - set GE-Proton in the REAL CompatToolMapping block"""
import sys, os, re, shutil, subprocess

PROTON = "GE-Proton10-34"

def find_config():
    for c in [
        "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/config/config.vdf",
        "~/.local/share/Steam/config/config.vdf",
        "~/.steam/steam/config/config.vdf",
        "~/.steam/debian-installation/config/config.vdf",
    ]:
        p = os.path.expanduser(c)
        if os.path.exists(p):
            return p
    return None

def steam_running():
    try:
        return subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0
    except Exception:
        return False

def read_aliases():
    out = []
    p = os.path.expanduser("~/.config/hpo/steam_aliases.txt")
    if os.path.exists(p):
        for line in open(p):
            line = line.strip()
            if line and "=" in line:
                v = line.split("=", 1)[1].strip()
                if v.isdigit():
                    out.append(v)
    return out

def set_in_compattoolmapping(content, appid):
    """Find the CompatToolMapping block and set/replace appid -> GE-Proton inside it."""
    # Locate the CompatToolMapping block
    m = re.search(r'"CompatToolMapping"\s*\{', content)
    if not m:
        return content, False
    start = m.end()
    # Find matching close brace for this block
    depth = 1
    i = start
    while i < len(content) and depth > 0:
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
        i += 1
    block_end = i  # position just after the closing }
    block = content[start:block_end-1]

    entry = (
        '\n\t\t\t\t\t"%s"\n\t\t\t\t\t{\n'
        '\t\t\t\t\t\t"name"\t\t"%s"\n'
        '\t\t\t\t\t\t"config"\t\t""\n'
        '\t\t\t\t\t\t"priority"\t\t"250"\n'
        '\t\t\t\t\t}\n' % (appid, PROTON)
    )

    # Does appid already exist in this block? Replace its inner name.
    pat = re.compile(r'("%s"\s*\{)(.*?)(\})' % re.escape(appid), re.S)
    mm = pat.search(block)
    if mm:
        inner = mm.group(2)
        if re.search(r'"name"\s*"[^"]*"', inner):
            inner_new = re.sub(r'("name"\s*")[^"]*(")', r'\g<1>%s\g<2>' % PROTON, inner, count=1)
        else:
            inner_new = '\n\t\t\t\t\t\t"name"\t\t"%s"%s' % (PROTON, inner)
        block_new = block[:mm.start()] + mm.group(1) + inner_new + mm.group(3) + block[mm.end():]
    else:
        block_new = block + entry

    return content[:start] + block_new + content[block_end-1:], True

def main():
    if len(sys.argv) < 2:
        print("[ZHEN] Usage: zhen-force.py <appid|--all>", file=sys.stderr)
        sys.exit(1)
    arg = sys.argv[1].strip()
    if steam_running():
        print("[ZHEN] Steam is running! Close Steam first.", file=sys.stderr)
        sys.exit(3)
    cfg = find_config()
    if not cfg:
        print("[ZHEN] config.vdf not found", file=sys.stderr)
        sys.exit(2)

    if arg == "--all":
        appids = read_aliases()
        if not appids:
            print("[ZHEN] No game aliases found.", file=sys.stderr)
            print("[ZHEN] Add games to ~/.config/hpo/steam_aliases.txt first", file=sys.stderr)
            print("[ZHEN]   (e.g. echo 'kao=1370140' >> ~/.config/hpo/steam_aliases.txt)", file=sys.stderr)
            sys.exit(1)
    else:
        appids = [arg] if arg.isdigit() else []
        if not appids:
            print(f"[ZHEN] Invalid target: {arg}", file=sys.stderr)
            sys.exit(1)

    content = open(cfg, encoding="utf-8").read()
    shutil.copy(cfg, cfg + ".hpo-bak")

    count = 0
    for appid in appids:
        content, ok = set_in_compattoolmapping(content, appid)
        if ok:
            count += 1
            print(f"[ZHEN] set GE-Proton for AppID {appid}")
        else:
            print(f"[ZHEN] CompatToolMapping not found for {appid}", file=sys.stderr)

    open(cfg, "w", encoding="utf-8").write(content)
    print(f"[ZHEN] Done! {count} game(s) -> {PROTON}")
    print(f"       Backup: {os.path.basename(cfg)}.hpo-bak")

if __name__ == "__main__":
    main()
