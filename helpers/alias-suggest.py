#!/usr/bin/env python3
"""hpo alias suggester - suggests nearest alias on typo"""
import sys, os, difflib

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    query = sys.argv[1].strip()
    # which alias file? default steam, optional arg 2 = "epic"
    kind = sys.argv[2] if len(sys.argv) > 2 else "steam"
    fname = f"~/.config/hpo/{kind}_aliases.txt"
    path = os.path.expanduser(fname)
    if not os.path.exists(path):
        sys.exit(1)

    names = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or "=" not in line:
                continue
            name = line.split("=", 1)[0].strip()
            if name:
                names.append(name)

    close = difflib.get_close_matches(query, names, n=3, cutoff=0.4)
    if close:
        print("       Did you mean: " + ", ".join(close) + "?")
    else:
        print("       (see your aliases: cat ~/.config/hpo/%s_aliases.txt)" % kind)

if __name__ == "__main__":
    main()
