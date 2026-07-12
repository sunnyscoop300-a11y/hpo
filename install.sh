#!/usr/bin/env bash
#
# hpo installer — bygger Hare fra kilde og installerer hpo
# Til nye Linux-brugere: én kommando ordner det hele.
#
#   curl -fsSL https://raw.githubusercontent.com/sunnyscoop300-a11y/hpo/main/install.sh | bash
#
# Understøtter Debian/Ubuntu/Mint/Zorin (apt). Andre distroer: se README.
set -euo pipefail

# ---------- farver ----------
G="\033[32m"; Y="\033[33m"; B="\033[34m"; R="\033[31m"; C="\033[36m"; X="\033[0m"
say()  { echo -e "${C}[hpo]${X} $*"; }
ok()   { echo -e "${G}[ok]${X} $*"; }
warn() { echo -e "${Y}[!]${X} $*"; }
die()  { echo -e "${R}[fejl]${X} $*" >&2; exit 1; }

banner() {
cat <<'EOF'
  _    _  _____   ___
 | |  | ||  __ \ / _ \
 | |__| || |__) | | | |
 |  __  ||  ___/| | | |
 | |  | || |    | |_| |
 |_|  |_||_|     \___/
  hpo installer — Skadoosh!
EOF
}

# ---------- 0. tjek platform ----------
banner
[ "$(uname -s)" = "Linux" ] || die "hpo kræver Linux."
command -v apt-get >/dev/null 2>&1 || die "Dette script understøtter apt (Debian/Ubuntu/Mint/Zorin). Se README for andre distroer."
[ "$(id -u)" -ne 0 ] || die "Kør IKKE som root. Scriptet beder selv om sudo når det er nødvendigt."

WORK="${HOME}/.cache/hpo-install"
mkdir -p "$WORK"

# ---------- 1. build-afhængigheder ----------
say "Installerer build-værktøjer (gcc, git, make m.m.)..."
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential git curl make gcc binutils \
    nodejs >/dev/null
ok "Build-værktøjer klar."

# ---------- 2. qbe (Hares backend) ----------
if ! command -v qbe >/dev/null 2>&1; then
    say "Bygger qbe (Hares compiler-backend)..."
    cd "$WORK"
    rm -rf qbe
    git clone --depth 1 git://c9x.me/qbe.git qbe 2>/dev/null \
        || git clone --depth 1 https://github.com/8l/qbe.git qbe
    cd qbe && make -s && sudo make -s install PREFIX=/usr/local
    ok "qbe installeret."
else
    ok "qbe findes allerede."
fi

# ---------- 3. scdoc (man-sider) ----------
if ! command -v scdoc >/dev/null 2>&1; then
    say "Bygger scdoc..."
    cd "$WORK"
    rm -rf scdoc
    git clone --depth 1 https://git.sr.ht/~sircmpwn/scdoc
    cd scdoc && make -s && sudo make -s install PREFIX=/usr/local
    ok "scdoc installeret."
else
    ok "scdoc findes allerede."
fi

# ---------- 4. harec (bootstrap-compiler) ----------
if ! command -v harec >/dev/null 2>&1; then
    say "Bygger harec (Hare bootstrap-compiler)..."
    cd "$WORK"
    rm -rf harec
    git clone --depth 1 https://git.sr.ht/~sircmpwn/harec
    cd harec
    [ -f config.example.mk ] && cp -n config.example.mk config.mk || true
    make -s && sudo make -s install
    ok "harec installeret."
else
    ok "harec findes allerede."
fi

# ---------- 5. hare (build driver + stdlib) ----------
if ! command -v hare >/dev/null 2>&1; then
    say "Bygger Hare (dette tager et par minutter)..."
    cd "$WORK"
    rm -rf hare
    git clone --depth 1 https://git.sr.ht/~sircmpwn/hare
    cd hare
    [ -f config.example.mk ] && cp -n config.example.mk config.mk || true
    make -s && sudo make -s install
    ok "Hare installeret."
else
    ok "Hare findes allerede."
fi

command -v hare >/dev/null 2>&1 || die "Hare-installation fejlede. Se https://harelang.org/documentation/install/"

# ---------- 6. klon + byg hpo ----------
say "Henter og bygger hpo..."
cd "$WORK"
rm -rf hpo
git clone --depth 1 https://github.com/sunnyscoop300-a11y/hpo
cd hpo
hare build -o hpo src/
sudo cp hpo /usr/local/bin/hpo
ok "hpo installeret til /usr/local/bin/hpo"

# ---------- 7. færdig ----------
echo
hpo --version 2>/dev/null || true
echo
ok "Installation færdig! 🐉"
echo
say "Næste skridt:"
echo -e "  ${B}hpo --setup${X}      installer gaming-motoren (Zhen, GE-Proton, SteamCMD)"
echo -e "  ${B}hpo -h${X}           se alle kommandoer"
echo -e "  ${B}hpo <url>${X}        download en fil"
echo
say "God fornøjelse — Skadoosh!"
