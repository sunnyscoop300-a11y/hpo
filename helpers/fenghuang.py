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
    if have("snap"):
        print(f"{INDIGO}>>{RST} Tjekker snaps...")
        run("snap","refresh","--list")


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
    if have("snap"):
        print(f"{INDIGO}>>{RST} Opdaterer snaps...")
        run("sudo","snap","refresh")
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
    if have("snap"):
        print(f"{INDIGO}>>{RST} Rydder gamle snap-versioner...")
        try:
            result = subprocess.run(["snap","list","--all"], capture_output=True, text=True)
            for line in result.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 6 and "disabled" in parts[5].lower():
                    run("sudo","snap","remove",parts[0],"--revision="+parts[2])
        except FileNotFoundError:
            pass


def install(backend, package):
    if backend == "apt":
        if not have("apt"):
            sys.exit("Fenghuang: apt findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via apt...")
        run("sudo","apt","install","-y",package)
    elif backend == "flatpak":
        if not have("flatpak"):
            sys.exit("Fenghuang: flatpak findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via flatpak...")
        run("flatpak","install","-y",package)
    elif backend == "snap":
        if not have("snap"):
            sys.exit("Fenghuang: snap findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via snap...")
        run("sudo","snap","install",package)
    else:
        sys.exit(f"Fenghuang: ukendt backend '{backend}'. Brug apt, flatpak eller snap.")
    print(f"{EYES}++{MOON} Installation fuldfoert.{RST}")


def main():
    banner()
    pm, lbl = detect_pm()
    if pm is None and not have("flatpak") and not have("snap"):
        sys.exit("Fenghuang: ingen pakkemanager fundet.")
    args = sys.argv[1:]
    if not args:
        check(pm, lbl); return
    cmd = args[0]
    if cmd in ("--upgrade","-u","upgrade"):
        upgrade(pm)
    elif cmd in ("--clean","-c","clean"):
        clean(pm)
    elif cmd in ("--all","-a","all"):
        upgrade(pm); clean(pm)
    elif cmd == "install":
        if len(args) < 3:
            sys.exit("Brug: hpo fenghuang install <apt|flatpak|snap> <pakke>")
        install(args[1], args[2])
    else:
        sys.exit(f"Fenghuang: ukendt flag '{cmd}'")


if __name__ == "__main__":
    main()
