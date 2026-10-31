#!/bin/sh
# Ding - PlayStation launcher for hpo (Master Ding and his spirit orbs)
#   ding.sh            menu of your PS1 / PS2 / PSP / PS3 games
#   ding.sh setup      install the emulators + make the game folders
#
# Games:  ~/.local/share/hpo/arcade/ps1  .cue .chd .pbp .m3u .iso
#                                   ps2  .iso .chd .cso .gz
#                                   psp  .iso .cso .pbp .chd
#                                   ps3  one folder per game (with PS3_GAME/USRDIR/EBOOT.BIN)
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

	say "[1/4] PS2 - PCSX2"
	have_flatpak_app net.pcsx2.PCSX2 || flatpak install -y flathub net.pcsx2.PCSX2
	flatpak override --user --filesystem="$BASE:ro" net.pcsx2.PCSX2
	say "[2/4] PSP - PPSSPP"
	have_flatpak_app org.ppsspp.PPSSPP || flatpak install -y flathub org.ppsspp.PPSSPP
	say "[3/4] PS3 - RPCS3"
	have_flatpak_app net.rpcs3.RPCS3 || flatpak install -y flathub net.rpcs3.RPCS3

	say "[4/4] PS1 - DuckStation (AppImage)"
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

	echo ""
	say "BIOS/firmware fra dine egne konsoller:"
	say "  PS1: DuckStation -> Settings -> BIOS"
	say "  PS2: PCSX2 -> foerste opstart spoerger efter BIOS"
	say "  PS3: RPCS3 -> File -> Install Firmware (PS3UPDAT.PUP)"
	say "  PSP: kraever ingen BIOS"
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
	esac
}

menu() {
	banner
	list_games
	if [ "$COUNT" = 0 ]; then
		say "Ingen spil endnu. Koer: hpo ding setup"
		say "og laeg spil i $BASE/ps1, ps2, psp eller ps3"
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
