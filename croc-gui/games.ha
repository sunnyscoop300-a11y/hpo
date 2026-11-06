// hpo croc — the 18 arcade games: how to tell if one is installed, how to
// install it and how to start it. The same games and commands as the
// `hpo croc` terminal menu in src/main.ha.
use fmt;
use fs;
use io;
use os;
use os::exec;
use strings;

type kind = enum { FLATPAK, SPELUNKY, KEEN4, WOLF3D };

type game = struct {
	name: str,       // on the card
	full: str,       // in the info bar
	genre: str,
	about: str,
	k: kind,
	appid: str,      // flatpak id (Keen 4: DOSBox Staging)
	icon: int,       // which drawing, see icons.ha
	col: u32,        // the card's colour
};

const GAMES: [18]game = [
	game { name = "Space Cadet", full = "Space Cadet Pinball", genre = "Pinball",
		about = "Den klassiske flipperspil fra Windows XP.", k = kind::FLATPAK,
		appid = "com.github.k4zmu2a.spacecadetpinball", icon = 0, col = 0xff3a6ad8 },
	game { name = "LBreakout HD", full = "LBreakout HD", genre = "Breakout",
		about = "Smadr murstenene med bold og bat.", k = kind::FLATPAK,
		appid = "net.sourceforge.lgames.LBreakoutHD", icon = 1, col = 0xffd8603a },
	game { name = "OpenTyrian", full = "OpenTyrian", genre = "Shooter",
		about = "Lodret rumskyder fra 90'erne.", k = kind::FLATPAK,
		appid = "com.github.opentyrian.OpenTyrian", icon = 2, col = 0xff4a8ae0 },
	game { name = "Frozen Bubble", full = "Frozen Bubble", genre = "Puzzle",
		about = "Skyd bobler op og saml tre i samme farve.", k = kind::FLATPAK,
		appid = "org.frozen_bubble.frozen-bubble", icon = 3, col = 0xff3ab8d8 },
	game { name = "Nanosaur", full = "Nanosaur", genre = "3D dino",
		about = "Red dinosaur-æggene i Pangeas jungle.", k = kind::FLATPAK,
		appid = "io.jor.nanosaur", icon = 4, col = 0xff5aa83a },
	game { name = "Sonic Robo Blast", full = "Sonic Robo Blast 2", genre = "3D platform",
		about = "Fart, ringe og loops i 3D.", k = kind::FLATPAK,
		appid = "org.srb2.SRB2", icon = 5, col = 0xff2a5ad8 },
	game { name = "SRB2 Kart", full = "SRB2 Kart", genre = "Racing",
		about = "Kart-ræs med drift og power-ups.", k = kind::FLATPAK,
		appid = "org.srb2.SRB2Kart", icon = 6, col = 0xffd83a3a },
	game { name = "Pixel Dungeon", full = "Shattered Pixel Dungeon", genre = "Roguelike",
		about = "Gå ned i fangekælderen, ét felt ad gangen.", k = kind::FLATPAK,
		appid = "com.shatteredpixel.shatteredpixeldungeon", icon = 7, col = 0xff8a6a4a },
	game { name = "SuperTux", full = "SuperTux", genre = "Platform",
		about = "Hop og løb gennem isverdenen.", k = kind::FLATPAK,
		appid = "org.supertuxproject.SuperTux", icon = 8, col = 0xffe8b83a },
	game { name = "SuperTuxKart", full = "SuperTuxKart", genre = "Racing",
		about = "3D kart-racing med baner og power-ups.", k = kind::FLATPAK,
		appid = "net.supertuxkart.SuperTuxKart", icon = 9, col = 0xff3aa8a8 },
	game { name = "OpenSurge", full = "OpenSurge", genre = "Platform",
		about = "Retro 2D-platformer med høj fart.", k = kind::FLATPAK,
		appid = "org.opensurge2d.OpenSurge", icon = 10, col = 0xffd8a83a },
	game { name = "Dynablaster", full = "Dynablaster Revenge", genre = "Bomberman",
		about = "Læg bomber og spræng dine venner.", k = kind::FLATPAK,
		appid = "com.github.varnholt.dynablaster_revenge", icon = 11, col = 0xff6a6a7a },
	game { name = "Ricochlime", full = "Ricochlime", genre = "Retro shooter",
		about = "Lad kuglerne prelle af og ram slimet.", k = kind::FLATPAK,
		appid = "com.adilhanney.ricochlime", icon = 12, col = 0xff6ad85a },
	game { name = "KMahjongg", full = "KMahjongg", genre = "Mahjong",
		about = "Mahjong-kabale fra KDE.", k = kind::FLATPAK,
		appid = "org.kde.kmahjongg", icon = 13, col = 0xffc84a4a },
	game { name = "GNOME Mahjongg", full = "GNOME Mahjongg", genre = "Mahjong",
		about = "Mahjong-kabale fra GNOME.", k = kind::FLATPAK,
		appid = "org.gnome.Mahjongg", icon = 13, col = 0xff4a8a5a },
	game { name = "Spelunky HD", full = "Spelunky Classic HD", genre = "Platform",
		about = "Grotter, skatte og fælder. AppImage.", k = kind::SPELUNKY,
		appid = "", icon = 14, col = 0xffb8783a },
	game { name = "Commander Keen 4", full = "Commander Keen 4", genre = "DOS",
		about = "Keen i DOSBox Staging. Henter filerne selv.", k = kind::KEEN4,
		appid = "io.github.dosbox-staging", icon = 15, col = 0xff8a3ad8 },
	game { name = "Wolfenstein 3D", full = "Wolfenstein 3D", genre = "DOS (ECWolf)",
		about = "Shareware-filerne (*.wl1) i ~/Games/Wolf3D.", k = kind::WOLF3D,
		appid = "", icon = 16, col = 0xff7a7a8a },
];

// Files for logs and lists, in /tmp so they never get in the way.
fn tmpfile(buf: []u8, what: str) str = {
	const user = os::tryenv("USER", "bruger");
	return fmt::bsprintf(buf, "/tmp/hpo-croc-{}-{}", user, what)!;
};

fn read_file(path: str) str = {
	const f = match (os::open(path)) {
	case let f: io::file => yield f;
	case => return "";
	};
	defer io::close(f)!;
	const data = match (io::drain(f)) {
	case let d: []u8 => yield d;
	case => return "";
	};
	return match (strings::fromutf8(data)) {
	case let s: str => yield s;
	case =>
		free(data);
		yield "";
	};
};

fn home(buf: []u8, rest: str) str =
	fmt::bsprintf(buf, "{}{}", os::tryenv("HOME", "/root"), rest)!;

fn exists(path: str) bool = os::stat(path) is fs::filestat;

fn on_path(prog: str) bool = match (exec::lookup(prog)) {
case str => yield true;     // statically allocated: not ours to free
case => yield false;
};

// Which games are installed, checked with one call to flatpak.
fn scan(ready: *[18]bool) void = {
	let buf: [256]u8 = [0...];
	const list = strings::dup(tmpfile(buf, "flatpaks"))!;
	defer free(list);
	let sbuf: [512]u8 = [0...];
	const script = fmt::bsprintf(sbuf,
		"flatpak list --app --columns=application > '{}' 2>/dev/null", list)!;
	match (run_wait(script)) {
	case => void;
	};
	const apps = read_file(list);
	defer free(apps);
	for (let i = 0z; i < len(GAMES); i += 1) {
		const g = &GAMES[i];
		ready[i] = switch (g.k) {
		case kind::FLATPAK, kind::KEEN4 => yield has_line(apps, g.appid);
		case kind::SPELUNKY =>
			let hb: [512]u8 = [0...];
			yield exists(home(hb, "/Applications/SpelunkyClassicHD.AppImage"));
		case kind::WOLF3D => yield on_path("ecwolf");
		};
	};
};

fn has_line(text: str, want: str) bool = {
	let it = strings::tokenize(text, "\n");
	for (let line => strings::next_token(&it)) {
		if (strings::trim(line) == want) return true;
	};
	return false;
};

// The shell command that installs game i (the same as `hpo croc setup`).
fn install_script(buf: []u8, i: size) str = {
	const g = &GAMES[i];
	return switch (g.k) {
	case kind::FLATPAK =>
		yield fmt::bsprintf(buf, "flatpak install -y flathub {}", g.appid)!;
	case kind::SPELUNKY =>
		yield "mkdir -p ~/Applications && wget -nc -q -O ~/Applications/SpelunkyClassicHD.AppImage https://github.com/yancharkin/SpelunkyClassicHD/releases/download/1.2.2/spelunky_classic_hd-linux-x86_64.AppImage; chmod +x ~/Applications/SpelunkyClassicHD.AppImage";
	case kind::KEEN4 =>
		yield "flatpak install -y flathub io.sourceforge.clonekeenplus io.github.dosbox-staging";
	case kind::WOLF3D =>
		yield "command -v ecwolf >/dev/null || hpo fenghuang install ecwolf; mkdir -p $HOME/Games/Wolf3D; ls $HOME/Games/Wolf3D/*.wl1 >/dev/null 2>&1 || echo '[CROC] Læg Wolf3D shareware-filerne (*.wl1) i ~/Games/Wolf3D'";
	};
};

// The shell command that starts game i (the same as the terminal menu).
fn launch_script(buf: []u8, i: size) str = {
	const g = &GAMES[i];
	return switch (g.k) {
	case kind::FLATPAK => yield fmt::bsprintf(buf, "flatpak run {}", g.appid)!;
	case kind::SPELUNKY => yield "~/Applications/SpelunkyClassicHD.AppImage";
	case kind::KEEN4 =>
		yield "K=$HOME/Games/Keen4; CG=\"$HOME/.var/app/io.sourceforge.clonekeenplus/config/CommanderGenius/games/Keen 4/keen4\"; if [ ! -f \"$K/KEEN4E.EXE\" ] && [ -f \"$CG/KEEN4E.EXE\" ]; then mkdir -p \"$HOME/Games\" && cp -r \"$CG\" \"$K\"; fi; if [ -f \"$K/KEEN4E.EXE\" ]; then flatpak run io.github.dosbox-staging -c \"mount c $K\" -c \"c:\" -c \"KEEN4E.EXE /detour\" -c \"exit\"; else echo \"[CROC] Keen 4-filerne mangler. Commander Genius starter, så den kan hente dem. Luk den og start Keen 4 igen.\"; flatpak run io.sourceforge.clonekeenplus; fi";
	case kind::WOLF3D =>
		yield "W=$HOME/Games/Wolf3D; if ! command -v ecwolf >/dev/null; then echo \"[CROC] ECWolf mangler. Tryk I for at installere.\"; elif ! ls \"$W\"/*.wl1 >/dev/null 2>&1; then echo \"[CROC] Wolf3D-filerne mangler. Læg *.wl1 i $W\"; else if [ ! -e \"$W/ecwolf.pk3\" ]; then for p in /usr/share/ecwolf/ecwolf.pk3 /usr/local/share/ecwolf/ecwolf.pk3; do [ -e \"$p\" ] && ln -s \"$p\" \"$W/\" && break; done; fi; cd \"$W\" && ecwolf --data wl1; fi";
	};
};

// Starts a shell command in the background with its output in the log.
fn run_logged(script: str, log: str) (exec::process | exec::error | nomem) = {
	const full = fmt::asprintf("exec > '{}' 2>&1 < /dev/null; {}", log, script)?;
	defer free(full);
	let cmd = exec::cmd("sh", "-c", full)?;
	return exec::start(&cmd);
};

// Runs a shell command and waits for it.
fn run_wait(script: str) (void | exec::error | nomem) = {
	let cmd = exec::cmd("sh", "-c", script)?;
	let proc = exec::start(&cmd)?;
	exec::wait(&proc)?;
};

// The last line of a log; flatpak redraws its progress with \r, so the
// last piece after one counts.
fn last_line(buf: []u8, log: str) str = {
	const text = read_file(log);
	defer free(text);
	const t = strings::rtrim(text);
	let line = if (strings::contains(t, "\n")) strings::rcut(t, "\n").1 else t;
	line = strings::rtrim(line, '\r');
	if (strings::contains(line, "\r")) line = strings::rcut(line, "\r").1;
	line = strings::trim(line);
	const b = strings::toutf8(line);
	// Keep it short enough for the window, on a character boundary.
	let n = if (len(b) > 90) 90z else len(b);
	for (n > 0 && n < len(b) && b[n] & 0xc0 == 0x80) n -= 1;
	buf[..n] = b[..n];
	return strings::fromutf8_unsafe(buf[..n]);
};

// Lines the scripts print for the player, starting with "[CROC]".
fn croc_message(buf: []u8, log: str) str = {
	const text = read_file(log);
	defer free(text);
	let it = strings::tokenize(text, "\n");
	for (let line => strings::next_token(&it)) {
		if (strings::hasprefix(line, "[CROC] ")) {
			const b = strings::toutf8(strings::trimprefix(line, "[CROC] "));
			let n = if (len(b) > len(buf)) len(buf) else len(b);
			for (n > 0 && n < len(b) && b[n] & 0xc0 == 0x80) n -= 1;
			buf[..n] = b[..n];
			return strings::fromutf8_unsafe(buf[..n]);
		};
	};
	return "";
};
