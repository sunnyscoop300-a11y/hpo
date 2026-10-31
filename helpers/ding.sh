#!/bin/sh
# Ding - PlayStation launcher for hpo (Master Ding and his spirit orbs)
#   ding.sh            menu of your PS1 / PS2 / PSP / PS3 / Vita games
#   ding.sh setup      install the emulators + make the game folders
#
# Games:  ~/.local/share/hpo/arcade/ps1  .cue .chd .pbp .m3u .iso
#                                   ps2  .iso .chd .cso .gz
#                                   psp  .iso .cso .pbp .chd
#                                   ps3  one folder per game (with PS3_GAME/USRDIR/EBOOT.BIN)
# Vita:   install .pkg/.vpk inside Vita3K once (File -> Install); Ding then lists
#         everything installed in Vita3K's ux0/app and starts it with Vita3K -r <TITLE-ID>
# BIOS / firmware must come from your own consoles.

BASE="$HOME/.local/share/hpo/arcade"
APPDIR="$HOME/Applications"

say() { printf '   [DING] %s\n' "$1"; }

banner() {
	printf '\033[33m'
	echo ""
	echo "   +-------------------------------+"
	echo "   |   MASTER DING                 |"
	echo "   |   PlayStation Spirit Orbs     |"
	echo "   +-------------------------------+"
	echo "        o    O    o     (the orbs begin to glow...)"
	echo "          \\  |  /"
	echo "         ( >o.o< )"
	echo "          /  @  \\"
	printf '\033[0m'
	echo ""
}

have_flatpak_app() { flatpak info "$1" >/dev/null 2>&1; }

vita3k_cmd() {
	for f in "$APPDIR"/Vita3K*.AppImage "$HOME"/.local/bin/Vita3K*.AppImage; do
		[ -x "$f" ] && { echo "$f"; return 0; }
	done
	command -v Vita3K >/dev/null 2>&1 && { echo Vita3K; return 0; }
	return 1
}

# where Vita3K keeps installed games (ux0/app/<TITLE-ID>)
vita_app_dir() {
	pp=$(sed -n 's/^pref-path: *//p' "$HOME/.config/Vita3K/config.yml" 2>/dev/null | tr -d "\"'" | head -1)
	for d in "$pp/ux0/app" "$HOME/.local/share/Vita3K/Vita3K/ux0/app" "$HOME/.local/share/Vita3K/ux0/app"; do
		[ -n "$d" ] && [ -d "$d" ] && { echo "$d"; return 0; }
	done
	return 1
}

# game name from sce_sys/param.sfo (falls back to the title ID)
vita_title() {
	python3 - "$1/sce_sys/param.sfo" 2>/dev/null <<'PY' || basename "$1"
import struct, sys
d = open(sys.argv[1], "rb").read()
k, v, n = struct.unpack_from("<III", d, 8)
for i in range(n):
    ko, fmt, ln, mx, do = struct.unpack_from("<HHIII", d, 20 + i * 16)
    key = d[k + ko:d.index(b"\0", k + ko)].decode()
    if key == "TITLE":
        print(d[v + do:v + do + ln].rstrip(b"\0").decode("utf-8", "replace").replace("\n", " "))
        sys.exit(0)
sys.exit(1)
PY
}

duckstation_cmd() {
	for f in "$APPDIR"/DuckStation*.AppImage "$HOME"/.local/bin/DuckStation*.AppImage; do
		[ -x "$f" ] && { echo "$f"; return 0; }
	done
	command -v duckstation-qt >/dev/null 2>&1 && { echo duckstation-qt; return 0; }
	have_flatpak_app org.duckstation.DuckStation && { echo "flatpak run org.duckstation.DuckStation"; return 0; }
	return 1
}

do_setup() {
	banner
	mkdir -p "$BASE/ps1" "$BASE/ps2" "$BASE/psp" "$BASE/ps3" "$APPDIR"
	say "Spillemapper klar i $BASE (ps1 ps2 psp ps3)"

	say "[1/5] PS2 - PCSX2"
	have_flatpak_app net.pcsx2.PCSX2 || flatpak install -y flathub net.pcsx2.PCSX2
	flatpak override --user --filesystem="$BASE:ro" net.pcsx2.PCSX2
	say "[2/5] PSP - PPSSPP"
	have_flatpak_app org.ppsspp.PPSSPP || flatpak install -y flathub org.ppsspp.PPSSPP
	say "[3/5] PS3 - RPCS3"
	have_flatpak_app net.rpcs3.RPCS3 || flatpak install -y flathub net.rpcs3.RPCS3

	say "[4/5] PS1 - DuckStation (AppImage)"
	if duckstation_cmd >/dev/null; then
		say "DuckStation findes allerede"
	else
		url="https://github.com/stenzek/duckstation/releases/download/latest/DuckStation-x64.AppImage"
		if curl -fL --progress-bar -o "$APPDIR/DuckStation-x64.AppImage" "$url"; then
			chmod +x "$APPDIR/DuckStation-x64.AppImage"
			say "DuckStation hentet til $APPDIR"
		else
			rm -f "$APPDIR/DuckStation-x64.AppImage"
			say "Kunne ikke hente DuckStation automatisk."
			say "Hent AppImage fra https://github.com/stenzek/duckstation/releases og laeg den i $APPDIR"
		fi
	fi

	say "[5/5] Vita - Vita3K (AppImage)"
	if vita3k_cmd >/dev/null; then
		say "Vita3K findes allerede"
	else
		url="https://github.com/Vita3K/Vita3K/releases/download/continuous/Vita3K-x86_64.AppImage"
		if curl -fL --progress-bar -o "$APPDIR/Vita3K-x86_64.AppImage" "$url"; then
			chmod +x "$APPDIR/Vita3K-x86_64.AppImage"
			say "Vita3K hentet til $APPDIR"
		else
			rm -f "$APPDIR/Vita3K-x86_64.AppImage"
			say "Kunne ikke hente Vita3K automatisk - hent AppImage fra vita3k.org og laeg den i $APPDIR"
		fi
	fi

	echo ""
	say "BIOS/firmware fra dine egne konsoller:"
	say "  PS1: DuckStation -> Settings -> BIOS"
	say "  PS2: PCSX2 -> foerste opstart spoerger efter BIOS"
	say "  PS3: RPCS3 -> File -> Install Firmware (PS3UPDAT.PUP)"
	say "  PSP: kraever ingen BIOS"
	say "  Vita: Vita3K -> File -> Install Firmware (PSVUPDAT.PUP + PSP2UPDAT.PUP)"
	say "        spil: Vita3K -> File -> Install .pkg / .vpk (kun een gang)"
	say "Klar! Laeg spil i mapperne og koer: hpo ding"
}

list_games() {
	i=1
	for sys in ps1 ps2 psp ps3; do
		d="$BASE/$sys"
		[ -d "$d" ] || continue
		for f in "$d"/*; do
			[ -e "$f" ] || continue
			ok=0
			case "$sys" in
			ps1) case "$f" in *.cue|*.CUE|*.chd|*.CHD|*.pbp|*.PBP|*.m3u|*.M3U|*.iso|*.ISO) ok=1 ;; esac ;;
			ps2) case "$f" in *.iso|*.ISO|*.chd|*.CHD|*.cso|*.CSO|*.gz|*.GZ) ok=1 ;; esac ;;
			psp) case "$f" in *.iso|*.ISO|*.cso|*.CSO|*.pbp|*.PBP|*.chd|*.CHD) ok=1 ;; esac ;;
			ps3) if [ -d "$f" ]; then
				eb=$(find "$f" -maxdepth 4 -path '*USRDIR/EBOOT.BIN' 2>/dev/null | head -1)
				[ -n "$eb" ] && ok=1
			     fi ;;
			esac
			[ "$ok" = 1 ] || continue
			tag=$(echo "$sys" | tr a-z A-Z)
			printf '   %2d  [%s] %s\n' "$i" "$tag" "$(basename "$f")"
			eval "g$i=\$f"
			eval "t$i=\$sys"
			i=$((i+1))
		done
	done
	vd=$(vita_app_dir)
	if [ -n "$vd" ]; then
		for g in "$vd"/*; do
			[ -d "$g" ] || continue
			id=$(basename "$g")
			printf '   %2d  [VITA] %s (%s)\n' "$i" "$(vita_title "$g")" "$id"
			eval "g$i=\$id"
			eval "t$i=vita"
			i=$((i+1))
		done
	fi
	COUNT=$((i-1))
}

launch() {
	sel="$1"; sys="$2"
	say "Ding sender en spirit orb ind i $(basename "$sel") [$(echo "$sys" | tr a-z A-Z)]..."
	case "$sys" in
	ps1)
		ds=$(duckstation_cmd) || { say "DuckStation mangler - koer: hpo ding setup"; return 1; }
		$ds "$sel" ;;
	ps2)
		have_flatpak_app net.pcsx2.PCSX2 || flatpak install -y flathub net.pcsx2.PCSX2
		flatpak run net.pcsx2.PCSX2 "$sel" ;;
	psp)
		have_flatpak_app org.ppsspp.PPSSPP || flatpak install -y flathub org.ppsspp.PPSSPP
		flatpak run org.ppsspp.PPSSPP "$sel" ;;
	ps3)
		have_flatpak_app net.rpcs3.RPCS3 || flatpak install -y flathub net.rpcs3.RPCS3
		eb=$(find "$sel" -maxdepth 4 -path '*USRDIR/EBOOT.BIN' 2>/dev/null | head -1)
		flatpak run net.rpcs3.RPCS3 --no-gui "$eb" ;;
	vita)
		v3k=$(vita3k_cmd) || { say "Vita3K mangler - koer: hpo ding setup"; return 1; }
		"$v3k" -r "$sel" ;;
	esac
}

menu() {
	banner
	list_games
	if [ "$COUNT" = 0 ]; then
		say "Ingen spil endnu. Koer: hpo ding setup"
		say "og laeg spil i $BASE/ps1, ps2, psp eller ps3 (Vita: installer i Vita3K)"
		exit 0
	fi
	echo "    q  Afslut"
	printf '   Vaelg: '
	read c
	[ "$c" = q ] && { say "Ding vender tilbage til sit faengsel paa Mugu Mountain..."; exit 0; }
	case "$c" in ''|*[!0-9]*) say "Ugyldigt valg"; exit 0 ;; esac
	eval "sel=\$g$c"; eval "sys=\$t$c"
	[ -n "$sel" ] || { say "Ugyldigt valg"; exit 0; }
	launch "$sel" "$sys"
}

case "$1" in
	setup) do_setup ;;
	*) menu ;;
esac
