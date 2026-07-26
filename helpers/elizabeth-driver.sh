#!/bin/bash
# Elizabeth - hpo's driver-mester (Rooster Fighter themed, elegant & naadeloes)
# Usage: elizabeth-driver.sh <action>
#   check / (tom) -> inspicer alle drivere
#   install       -> installer manglende drivere
#   backup        -> gem driver-liste
#   restore       -> vis gemt driver-liste

ACTION="${1:-check}"
GOLD='\033[1;33m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
DIM='\033[2m'
RESET='\033[0m'
CONF="$HOME/.config/hpo"
mkdir -p "$CONF"

header() {
    echo -e "${GOLD}"
    echo "   ╔════════════════════════════╗"
    echo "   ║      E L I Z A B E T H       ║"
    echo "   ║      Driver Mistress         ║"
    echo "   ╚════════════════════════════╝"
    echo -e "${RESET}${DIM}      ╱▲╲"
    echo "     ( ◕ᴥ◕ )   \"Your machine will be flawless.\""
    echo -e "      \\\\_╱ ╲_${RESET}"
    echo ""
}

# Elegant status-linje: navn, status, detalje
line() {
    local name="$1" ok="$2" detail="$3"
    if [ "$ok" = "1" ]; then
        echo -e "   ${GREEN}✓${RESET} ${GOLD}$name${RESET}  ${DIM}$detail${RESET}"
    else
        echo -e "   ${RED}✗${RESET} ${GOLD}$name${RESET}  ${DIM}$detail${RESET}"
    fi
}

check_drivers() {
    header
    echo -e "${CYAN}   [ELIZABETH] Inspecting your steed's equipment...${RESET}"
    echo ""

    # GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        gpu=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
        line "GPU (NVIDIA)" 1 "$gpu"
    elif lspci 2>/dev/null | grep -qi "VGA.*AMD\|VGA.*ATI"; then
        amd=$(lspci 2>/dev/null | grep -i "VGA.*AMD\|VGA.*ATI" | head -1 | cut -d: -f3)
        line "GPU (AMD)" 1 "$amd (Mesa)"
    elif lspci 2>/dev/null | grep -qi "VGA.*Intel"; then
        intel=$(lspci 2>/dev/null | grep -i "VGA.*Intel" | head -1 | cut -d: -f3)
        line "GPU (Intel)" 1 "$intel"
    else
        line "GPU" 0 "ingen genkendt driver"
    fi

    # Vulkan
    if command -v vulkaninfo >/dev/null 2>&1; then
        vk=$(vulkaninfo --summary 2>/dev/null | grep -i "deviceName" | head -1 | cut -d= -f2 | xargs)
        line "Vulkan" 1 "${vk:-tilgaengelig}"
    else
        line "Vulkan" 0 "vulkan-tools ikke installeret"
    fi

    # Printer
    if command -v lpstat >/dev/null 2>&1; then
        prn=$(lpstat -p 2>/dev/null | grep -i "printer" | head -1 | awk '{print $2}')
        if [ -n "$prn" ]; then
            line "Printer" 1 "$prn"
        else
            line "Printer" 0 "ingen printer konfigureret"
        fi
    else
        line "Printer (CUPS)" 0 "cups ikke installeret"
    fi

    # Lyd
    if command -v pipewire >/dev/null 2>&1; then
        pw=$(pipewire --version 2>/dev/null | head -1)
        line "Audio (PipeWire)" 1 "$pw"
    elif command -v pulseaudio >/dev/null 2>&1; then
        line "Audio (PulseAudio)" 1 "aktiv"
    else
        line "Audio" 0 "ingen lyd-server fundet"
    fi

    # Netvaerk
    net=$(ip -brief link 2>/dev/null | grep -iv "lo " | grep -i "up" | head -1 | awk '{print $1}')
    if [ -n "$net" ]; then
        line "Network" 1 "$net (up)"
    else
        line "Network" 0 "ingen aktiv forbindelse"
    fi

    # Flatpak
    if command -v flatpak >/dev/null 2>&1; then
        fpcount=$(flatpak list 2>/dev/null | wc -l)
        line "Flatpak" 1 "$fpcount apps installeret"
    else
        line "Flatpak" 0 "ikke installeret"
    fi

    echo ""
    # Elizabeth's dom
    missing=0
    command -v nvidia-smi >/dev/null 2>&1 || lspci 2>/dev/null | grep -qi VGA || missing=1
    command -v lpstat >/dev/null 2>&1 || missing=1
    if [ "$missing" = "0" ]; then
        echo -e "${GOLD}   [ELIZABETH] \"Adequate. But I demand perfection.\"${RESET}"
    else
        echo -e "${RED}   [ELIZABETH] \"This will not do. Run: hpo elizabeth install\"${RESET}"
    fi
    echo ""
}

install_drivers() {
    header
    echo -e "${CYAN}   [ELIZABETH] \"Allow me to correct your machine's flaws...\"${RESET}"
    echo ""

    # Vulkan tools (til GPU-diagnostik)
    if ! command -v vulkaninfo >/dev/null 2>&1; then
        echo -e "${GOLD}   Installing vulkan-tools...${RESET}"
        sudo apt install -y vulkan-tools mesa-vulkan-drivers 2>&1 | tail -2
    fi

    # CUPS (printer)
    if ! command -v lpstat >/dev/null 2>&1; then
        echo -e "${GOLD}   Installing CUPS (printer support)...${RESET}"
        sudo apt install -y cups cups-client system-config-printer printer-driver-all avahi-daemon 2>&1 | tail -2
    fi

    # Flatpak
    if ! command -v flatpak >/dev/null 2>&1; then
        echo -e "${GOLD}   Installing Flatpak...${RESET}"
        sudo apt install -y flatpak 2>&1 | tail -2
    fi

    # NVIDIA (kun forslag - foelsomt at auto-installere)
    if lspci 2>/dev/null | grep -qi "VGA.*NVIDIA" && ! command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "${RED}   NVIDIA GPU fundet men ingen driver!${RESET}"
        echo -e "${DIM}   Elizabeth foreslaar: sudo apt install nvidia-driver firmware-misc-nonfree${RESET}"
    fi

    echo ""
    echo -e "${GOLD}   [ELIZABETH] \"Now your machine is... worthy.\"${RESET}"
    echo ""
}

backup_drivers() {
    header
    local f="$CONF/elizabeth-drivers.txt"
    echo -e "${CYAN}   [ELIZABETH] \"I shall record your equipment for posterity...\"${RESET}"
    {
        echo "# Elizabeth driver backup - $(date)"
        echo "## GPU"
        lspci 2>/dev/null | grep -i VGA
        command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null
        echo "## Printers"
        lpstat -p 2>/dev/null
        echo "## Audio"
        command -v pipewire >/dev/null 2>&1 && pipewire --version 2>/dev/null
        echo "## Flatpaks"
        flatpak list --app 2>/dev/null | awk '{print $1}'
        echo "## Kernel"
        uname -r
    } > "$f"
    echo ""
    echo -e "${GREEN}   Gemt: $f${RESET}"
    echo -e "${GOLD}   [ELIZABETH] \"Your steed's history is preserved.\"${RESET}"
    echo ""
}

restore_drivers() {
    header
    local f="$CONF/elizabeth-drivers.txt"
    if [ ! -f "$f" ]; then
        echo -e "${RED}   [ELIZABETH] \"There is no record to restore. Run: hpo elizabeth backup\"${RESET}"
        echo ""
        return
    fi
    echo -e "${CYAN}   [ELIZABETH] \"Behold your machine's recorded equipment:\"${RESET}"
    echo ""
    cat "$f" | while IFS= read -r ln; do echo -e "   ${DIM}$ln${RESET}"; done
    echo ""
    echo -e "${GOLD}   [ELIZABETH] \"Use this to restore your setup on any machine.\"${RESET}"
    echo ""
}

case "$ACTION" in
    check|"") check_drivers ;;
    install)  install_drivers ;;
    backup)   backup_drivers ;;
    restore)  restore_drivers ;;
    *)        check_drivers ;;
esac
