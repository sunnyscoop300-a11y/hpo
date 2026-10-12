#!/usr/bin/env python3
"""Fenghuang - hpo system package updater
Supports apt, pacman, dnf, zypper + flatpak + snap"""
import os, shutil, subprocess, sys

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
    for cmd, pm, lbl in [
        ("apt","apt","apt"),
        ("pacman","pacman","pacman"),
        ("dnf","dnf","dnf"),
        ("zypper","zypper","zypper"),
        ("xbps-install","xbps","xbps"),
    ]:
        if have(cmd):
            return pm, lbl
    return None, "ingen"


def auto_backend(package, pm):
    """Pick backend when user didn't specify one."""
    if package.endswith(".snap"):
        return "snap"
    if package.endswith(".flatpak") or package.endswith(".flatpakref"):
        return "flatpak"
    if package.endswith(".deb"):
        return "apt"
    if package.endswith(".rpm"):
        return "dnf" if have("dnf") else "zypper"
    if package.endswith(".pkg.tar.zst") or package.endswith(".pkg.tar.xz"):
        return "pacman"
    if package.endswith(".xbps"):
        return "xbps"
    if package.count(".") >= 2 and "/" not in package:
        return "flatpak"
    return pm or "apt"


def run(*args):
    try:
        result = subprocess.run(list(args), check=False)
        return result.returncode == 0
    except FileNotFoundError:
        return False


def check(pm, lbl):
    print(f"{INDIGO}>>{RST} Tjekker system-pakker ({lbl})...")
    if pm == "apt":
        run("sudo","apt","update"); run("apt","list","--upgradable")
    elif pm == "pacman":
        if have("checkupdates"):
            run("checkupdates")
        else:
            run("pacman","-Qu")
    elif pm == "dnf":
        run("dnf","check-update")
    elif pm == "zypper":
        run("sudo","zypper","refresh"); run("zypper","list-updates")
    elif pm == "xbps":
        run("sudo","xbps-install","-Sun")
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
    elif pm == "xbps":
        run("sudo","xbps-install","-Suy")
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
        # Also remove orphaned packages
        try:
            result = subprocess.run(["pacman","-Qdtq"], capture_output=True, text=True)
            orphans = result.stdout.strip().split("\n")
            orphans = [o for o in orphans if o]
            if orphans:
                run("sudo","pacman","-Rns","--noconfirm",*orphans)
        except FileNotFoundError:
            pass
    elif pm == "dnf":
        run("sudo","dnf","autoremove","-y"); run("sudo","dnf","clean","all")
    elif pm == "zypper":
        run("sudo","zypper","clean")
    elif pm == "xbps":
        run("sudo","xbps-remove","-O","-y")
        run("sudo","xbps-remove","-o","-y")
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
    expanded = os.path.expanduser(package)
    is_local = os.path.isfile(expanded)
    ok = False
    if backend == "apt":
        if not have("apt"):
            sys.exit("Fenghuang: apt findes ikke paa dette system.")
        if is_local and package.endswith(".deb"):
            print(f"{INDIGO}>>{RST} Installerer lokal .deb-fil {BOLD}{package}{RST}...")
            ok = run("sudo","apt","install","-y",expanded)
        else:
            print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via apt...")
            ok = run("sudo","apt","install","-y",package)
    elif backend == "pacman":
        if not have("pacman"):
            sys.exit("Fenghuang: pacman findes ikke paa dette system.")
        if is_local and (package.endswith(".pkg.tar.zst") or package.endswith(".pkg.tar.xz")):
            print(f"{INDIGO}>>{RST} Installerer lokal pacman-pakke {BOLD}{package}{RST}...")
            ok = run("sudo","pacman","-U","--noconfirm",expanded)
        else:
            print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via pacman...")
            ok = run("sudo","pacman","-S","--noconfirm",package)
    elif backend == "dnf":
        if not have("dnf"):
            sys.exit("Fenghuang: dnf findes ikke paa dette system.")
        if is_local and package.endswith(".rpm"):
            print(f"{INDIGO}>>{RST} Installerer lokal .rpm-fil {BOLD}{package}{RST}...")
            ok = run("sudo","dnf","install","-y",expanded)
        else:
            print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via dnf...")
            ok = run("sudo","dnf","install","-y",package)
    elif backend == "zypper":
        if not have("zypper"):
            sys.exit("Fenghuang: zypper findes ikke paa dette system.")
        if is_local and package.endswith(".rpm"):
            print(f"{INDIGO}>>{RST} Installerer lokal .rpm-fil {BOLD}{package}{RST}...")
            ok = run("sudo","zypper","install","-y",expanded)
        else:
            print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via zypper...")
            ok = run("sudo","zypper","install","-y",package)
    elif backend == "xbps":
        if not have("xbps-install"):
            sys.exit("Fenghuang: xbps-install findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via xbps...")
        ok = run("sudo","xbps-install","-Sy",package)
    elif backend == "flatpak":
        if not have("flatpak"):
            sys.exit("Fenghuang: flatpak findes ikke paa dette system.")
        if is_local and (package.endswith(".flatpak") or package.endswith(".flatpakref")):
            print(f"{INDIGO}>>{RST} Installerer lokal flatpak-fil {BOLD}{package}{RST}...")
            ok = run("flatpak","install","-y",expanded)
        else:
            print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via flatpak...")
            ok = run("flatpak","install","-y",package)
    elif backend == "snap":
        if not have("snap"):
            sys.exit("Fenghuang: snap findes ikke paa dette system.")
        if is_local and package.endswith(".snap"):
            print(f"{INDIGO}>>{RST} Installerer lokal snap-fil {BOLD}{package}{RST} (--dangerous)...")
            ok = run("sudo","snap","install","--dangerous",expanded)
        else:
            print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} via snap...")
            ok = run("sudo","snap","install",package)
    else:
        sys.exit(f"Fenghuang: ukendt backend '{backend}'. Brug apt, pacman, dnf, zypper, flatpak eller snap.")
    if ok:
        print(f"{EYES}++{MOON} Installation fuldfoert.{RST}")
    else:
        print(f"{DIM}  Installation fejlede.{RST}")


def uninstall(backend, package):
    ok = False
    if backend == "apt":
        if not have("apt"):
            sys.exit("Fenghuang: apt findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via apt (+ autoremove)...")
        ok = run("sudo","apt","remove","-y","--autoremove",package)
    elif backend == "pacman":
        if not have("pacman"):
            sys.exit("Fenghuang: pacman findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via pacman (+ deps)...")
        ok = run("sudo","pacman","-Rns","--noconfirm",package)
    elif backend == "dnf":
        if not have("dnf"):
            sys.exit("Fenghuang: dnf findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via dnf...")
        ok = run("sudo","dnf","remove","-y",package)
    elif backend == "zypper":
        if not have("zypper"):
            sys.exit("Fenghuang: zypper findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via zypper...")
        ok = run("sudo","zypper","remove","-y",package)
    elif backend == "xbps":
        if not have("xbps-remove"):
            sys.exit("Fenghuang: xbps-remove findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via xbps (+ orphans)...")
        ok = run("sudo","xbps-remove","-Ry",package)
    elif backend == "flatpak":
        if not have("flatpak"):
            sys.exit("Fenghuang: flatpak findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via flatpak...")
        ok = run("flatpak","uninstall","-y",package)
    elif backend == "snap":
        if not have("snap"):
            sys.exit("Fenghuang: snap findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner {BOLD}{package}{RST} via snap...")
        ok = run("sudo","snap","remove",package)
    else:
        sys.exit(f"Fenghuang: ukendt backend '{backend}'. Brug apt, pacman, dnf, zypper, flatpak eller snap.")
    if ok:
        print(f"{EYES}++{MOON} Fjernelse fuldfoert.{RST}")
    else:
        print(f"{DIM}  Fjernelse fejlede.{RST}")


def search(backend, query):
    if backend == "all":
        if have("apt"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}apt{RST}...")
            run("apt","search",query); print()
        if have("pacman"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}pacman{RST}...")
            run("pacman","-Ss",query); print()
        if have("dnf"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}dnf{RST}...")
            run("dnf","search",query); print()
        if have("zypper"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}zypper{RST}...")
            run("zypper","search",query); print()
        if have("xbps-query"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}xbps{RST}...")
            run("xbps-query","-Rs",query); print()
        if have("flatpak"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}flatpak{RST}...")
            run("flatpak","search",query); print()
        if have("snap"):
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}snap store{RST}...")
            run("snap","find",query)
    elif backend == "apt":
        if not have("apt"):
            sys.exit("Fenghuang: apt findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i apt efter {BOLD}{query}{RST}...")
        run("apt","search",query)
    elif backend == "pacman":
        if not have("pacman"):
            sys.exit("Fenghuang: pacman findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i pacman efter {BOLD}{query}{RST}...")
        run("pacman","-Ss",query)
    elif backend == "dnf":
        if not have("dnf"):
            sys.exit("Fenghuang: dnf findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i dnf efter {BOLD}{query}{RST}...")
        run("dnf","search",query)
    elif backend == "zypper":
        if not have("zypper"):
            sys.exit("Fenghuang: zypper findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i zypper efter {BOLD}{query}{RST}...")
        run("zypper","search",query)
    elif backend == "xbps":
        if not have("xbps-query"):
            sys.exit("Fenghuang: xbps-query findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i xbps efter {BOLD}{query}{RST}...")
        run("xbps-query","-Rs",query)
    elif backend == "flatpak":
        if not have("flatpak"):
            sys.exit("Fenghuang: flatpak findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i flatpak efter {BOLD}{query}{RST}...")
        run("flatpak","search",query)
    elif backend == "snap":
        if not have("snap"):
            sys.exit("Fenghuang: snap findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Soeger i snap store efter {BOLD}{query}{RST}...")
        run("snap","find",query)
    else:
        sys.exit(f"Fenghuang: ukendt backend '{backend}'. Brug apt, pacman, dnf, zypper, flatpak, snap eller all.")


BACKENDS = {"apt","pacman","dnf","zypper","xbps","flatpak","snap"}


def resolve_backend_and_pkg(args, pm):
    """From args after 'install'/'uninstall', return (backend, package)."""
    if len(args) == 1:
        pkg = args[0]
        backend = auto_backend(pkg, pm)
        print(f"{DIM}  (auto-valgt backend: {backend}){RST}")
        return backend, pkg
    elif len(args) >= 2:
        if args[0] in BACKENDS:
            return args[0], args[1]
        else:
            pkg = args[0]
            backend = auto_backend(pkg, pm)
            print(f"{DIM}  (auto-valgt backend: {backend}){RST}")
            return backend, pkg
    return None, None


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
        if len(args) < 2:
            sys.exit("Brug: hpo fenghuang install [backend] <pakke|fil>")
        backend, pkg = resolve_backend_and_pkg(args[1:], pm)
        if backend is None:
            sys.exit("Brug: hpo fenghuang install [backend] <pakke|fil>")
        install(backend, pkg)
    elif cmd in ("uninstall","remove","-d","--delete"):
        if len(args) < 2:
            sys.exit("Brug: hpo fenghuang uninstall [backend] <pakke>")
        backend, pkg = resolve_backend_and_pkg(args[1:], pm)
        if backend is None:
            sys.exit("Brug: hpo fenghuang uninstall [backend] <pakke>")
        uninstall(backend, pkg)
    elif cmd in ("search","find","-s"):
        if len(args) < 2:
            sys.exit("Brug: hpo fenghuang search [backend|all] <soegeord>")
        if len(args) == 2:
            search("all", args[1])
        elif args[1] in BACKENDS or args[1] == "all":
            search(args[1], args[2])
        else:
            search("all", args[1])
    else:
        sys.exit(f"Fenghuang: ukendt flag '{cmd}'")


if __name__ == "__main__":
    main()
