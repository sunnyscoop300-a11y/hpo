#!/usr/bin/env python3
"""Fenghuang - hpo system package updater
Supports apt, pacman, dnf, zypper + flatpak + snap"""
import os, re, shutil, subprocess, sys

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


def aur_helper():
    """Return the installed AUR helper (yay or paru), or None."""
    for h in ("yay", "paru"):
        if have(h):
            return h
    return None


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


def _vkey(v):
    """Version sort key: '6.12.48+deb13' -> ['', 6, '.', 12, '.', 48, '+deb', 13, '']"""
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", v)]


def is_wsl():
    try:
        with open("/proc/version") as f:
            return "microsoft" in f.read().lower()
    except OSError:
        return False


def kernel_status(boot="/boot", modules="/lib/modules"):
    """Return (running, newest_installed_or_None, reboot_needed)."""
    running = os.uname().release
    newest = None
    try:
        vers = [f[len("vmlinuz-"):] for f in os.listdir(boot) if f.startswith("vmlinuz-")]
        # Arch names its files vmlinuz-linux / vmlinuz-linux-lts (no version number)
        vers = [v for v in vers if v[:1].isdigit()]
        if vers:
            newest = max(vers, key=_vkey)
    except OSError:
        pass
    reboot = False
    if not os.path.isdir(os.path.join(modules, running)):
        reboot = True   # running kernel's modules were replaced (Arch/Void after an upgrade)
    elif newest and _vkey(newest) > _vkey(running):
        reboot = True   # a newer kernel is installed next to the running one (Debian/Fedora)
    if os.path.exists("/var/run/reboot-required"):
        reboot = True   # Ubuntu/Mint flag
    return running, newest, reboot


def print_kernel_status(after_upgrade=False):
    if is_wsl():
        print(f"{DIM}  (WSL: kernen styres af Windows Update){RST}")
        return
    running, newest, reboot = kernel_status()
    line = f"{INDIGO}>>{RST} Kerne: koerer {BOLD}{running}{RST}"
    if newest and newest != running:
        line += f", nyeste installeret {BOLD}{newest}{RST}"
    print(line)
    if reboot:
        print(f"{EYES}!!{MOON} Ny kerne installeret - genstart for at tage den i brug.{RST}")
    elif after_upgrade:
        print(f"{DIM}  (ingen ny kerne denne gang){RST}")


def check(pm, lbl):
    print(f"{INDIGO}>>{RST} Tjekker system-pakker ({lbl})...")
    if pm == "apt":
        run("sudo","apt","update"); run("apt","list","--upgradable")
    elif pm == "pacman":
        if have("checkupdates"):
            run("checkupdates")
        else:
            run("pacman","-Qu")
        h = aur_helper()
        if h:
            print(f"{INDIGO}>>{RST} Tjekker AUR ({h})...")
            run(h,"-Qua")
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
    print_kernel_status()


def upgrade(pm):
    print(f"{MOON}**{RST} Opdaterer system-pakker...")
    if pm == "apt":
        # full-upgrade (not upgrade) so new kernel packages like linux-image-X are installed
        run("sudo","apt","update"); run("sudo","apt","full-upgrade","-y")
    elif pm == "pacman":
        h = aur_helper()
        if h:
            # yay/paru updates both the official repos and the AUR, and calls sudo itself
            print(f"{DIM}  (bruger {h}, saa AUR-pakker ogsaa bliver opdateret){RST}")
            run(h,"-Syu","--noconfirm")
        else:
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
    print_kernel_status(after_upgrade=True)
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
            h = aur_helper()
            if not ok and h:
                print(f"{DIM}  (ikke fundet i pacman - proever AUR med {h}){RST}")
                ok = run(h,"-S","--noconfirm",package)
    elif backend == "aur":
        h = aur_helper()
        if not h:
            sys.exit("Fenghuang: ingen AUR-helper fundet. Installer yay eller paru foerst.")
        print(f"{INDIGO}>>{RST} Installerer {BOLD}{package}{RST} fra AUR via {h}...")
        ok = run(h,"-S","--noconfirm",package)
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
    elif backend == "aur":
        # AUR packages are registered in pacman's database, so removal is the same
        if not have("pacman"):
            sys.exit("Fenghuang: pacman findes ikke paa dette system.")
        print(f"{INDIGO}>>{RST} Fjerner AUR-pakken {BOLD}{package}{RST} (+ deps)...")
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
        h = aur_helper()
        if h:
            print(f"{INDIGO}>>{RST} Soeger i {BOLD}AUR{RST} ({h})...")
            run(h,"-Ss","--aur",query); print()
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
    elif backend == "aur":
        h = aur_helper()
        if not h:
            sys.exit("Fenghuang: ingen AUR-helper fundet. Installer yay eller paru foerst.")
        print(f"{INDIGO}>>{RST} Soeger i AUR efter {BOLD}{query}{RST} ({h})...")
        run(h,"-Ss","--aur",query)
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


BACKENDS = {"apt","pacman","aur","dnf","zypper","xbps","flatpak","snap"}
# "yay" and "paru" are accepted as aliases for "aur"
BACKEND_ALIASES = {"yay": "aur", "paru": "aur"}


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
    if len(args) >= 2 and args[1] in BACKEND_ALIASES:
        args[1] = BACKEND_ALIASES[args[1]]
    if not args:
        check(pm, lbl); return
    cmd = args[0]
    if cmd in ("--upgrade","-u","upgrade"):
        upgrade(pm)
    elif cmd in ("--clean","-c","clean"):
        clean(pm)
    elif cmd in ("--all","-a","all"):
        upgrade(pm); clean(pm)
    elif cmd in ("kernel","-k","--kernel"):
        print_kernel_status()
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
