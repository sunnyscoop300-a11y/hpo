#!/usr/bin/env python3
"""Fenghuang - hpo system package updater"""
import shutil, subprocess, sys

INDIGO = "\x1b[38;5;93m"
MOON   = "\x1b[38;5;189m"
EYES   = "\x1b[38;5;226m"
RST    = "\x1b[0m"
BOLD   = "\x1b[1m"
DIM    = "\x1b[2m"


def banner():
    print(f"{INDIGO}         ,___,{RST}")
    print(f"{INDIGO}         ({EYES}O{INDIGO},{EYES}O{INDIGO})     {DIM}.  .  .{RST}")
    print(f"{INDIGO}        /)___)\\{RST}")
    print(f"{INDIGO}       --\"--\"--{RST}")
    print(f"{BOLD}{MOON}  FENGHUANG - den maegtigste pakke-opdatering{RST}")
    print(f"{DIM}  fra Northern Mountains{RST}\n")


def have(cmd):
    return shutil.which(cmd) is not None


def detect_pm():
    for pm, lbl in [("apt","apt"),("pacman","pacman"),("dnf","dnf"),("zypper","zypper")]:
        if have(pm):
            return pm, lbl
    return None, "ingen"


def run(*args):
    try:
        subprocess.run(list(args), check=False)
    except FileNotFoundError:
        pass


def check(pm, lbl):
    print(f"{INDIGO}>>{RST} Tjekker system-pakker ({lbl})...")
    if pm == "apt":
        run("sudo","apt","update"); run("apt","list","--upgradable")
    elif pm == "pacman":
        run("checkupdates")
    elif pm == "dnf":
        run("dnf","check-update")
    elif pm == "zypper":
        run("sudo","zypper","refresh"); run("zypper","list-updates")
    if have("flatpak"):
        print(f"{INDIGO}>>{RST} Tjekker flatpaks...")
        run("flatpak","remote-ls","--updates")


def upgrade(pm):
    print(f"{MOON}**{RST} Opdaterer system-pakker...")
    if pm == "apt":
        run("sudo","apt","update"); run("sudo","apt","upgrade","-y")
    elif pm == "pacman":
        run("sudo","pacman","-Syu","--noconfirm")
    elif pm == "dnf":
        run("sudo","dnf","upgrade","-y")
    elif pm == "zypper":
        run("sudo","zypper","update","-y")
    if have("flatpak"):
        print(f"{INDIGO}>>{RST} Opdaterer flatpaks...")
        run("flatpak","update","-y")
    print(f"{EYES}++{MOON} Fuldfoert.{RST}")


def clean(pm):
    print(f"{INDIGO}>>{RST} Rydder op...")
    if pm == "apt":
        run("sudo","apt","autoremove","-y"); run("sudo","apt","clean")
    elif pm == "pacman":
        run("sudo","pacman","-Sc","--noconfirm")
    elif pm == "dnf":
        run("sudo","dnf","autoremove","-y"); run("sudo","dnf","clean","all")
    elif pm == "zypper":
        run("sudo","zypper","clean")
    if have("flatpak"):
        print(f"{INDIGO}>>{RST} Rydder flatpaks...")
        run("flatpak","uninstall","--unused","-y")


def main():
    banner()
    pm, lbl = detect_pm()
    if pm is None and not have("flatpak"):
        sys.exit("Fenghuang: ingen pakkemanager fundet.")
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg == "":
        check(pm, lbl)
    elif arg in ("--upgrade","-u","upgrade"):
        upgrade(pm)
    elif arg in ("--clean","-c","clean"):
        clean(pm)
    elif arg in ("--all","-a","all"):
        upgrade(pm); clean(pm)
    else:
        sys.exit(f"Fenghuang: ukendt flag '{arg}'")


if __name__ == "__main__":
    main()
