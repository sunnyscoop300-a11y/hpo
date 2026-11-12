// hpo croc — CROC ARCADE, the retro arcade hub with a window, built on
// ViperGui. The first hpo command with a GUI. `hpo croc` starts it when
// there is a desktop; `hpo croc tui` gives the old terminal menu.
//
// Arrows/mouse pick a game, Enter plays it (or installs it if it's
// missing), I installs, A installs all 22, R checks again, Esc quits.
use fmt;
use math;
use os;
use os::exec;
use strings;
use viper;

def W: int = 1000;
def H: int = 840;
def COLS: size = 8;
def CW: int = 112;
def CH: int = 148;
def GAP: int = 12;
def GX: int = 10;
def GY: int = 116;
def ALL: size = 22;           // the "install everything" job

type mode = enum { BROWSE, PLAYING, INSTALLING };

type app = struct {
	sel: size,
	ready: [22]bool,
	mode: mode,
	proc: exec::process,
	job: size,          // the game being played or installed, or ALL
	job_t: f64,
	clock: f64,
	log: str,
	logbuf: [256]u8,
	msg: str,
	msgbuf: [160]u8,
	msg_t: f64,
	bg: viper::image,
};

fn say(a: *app, s: str) void = {
	const b = strings::toutf8(s);
	const n = if (len(b) > len(a.msgbuf)) len(a.msgbuf) else len(b);
	a.msgbuf[..n] = b[..n];
	a.msg = strings::fromutf8_unsafe(a.msgbuf[..n]);
	a.msg_t = 6.0;
};

fn nready(a: *app) int = {
	let n = 0;
	for (let r .. a.ready) if (r) n += 1;
	return n;
};

fn play(a: *app, i: size) void = {
	if (!a.ready[i]) {
		install(a, i);
		return;
	};
	let buf: [2048]u8 = [0...];
	match (run_logged(launch_script(buf, i), a.log)) {
	case let p: exec::process =>
		a.proc = p;
		a.mode = mode::PLAYING;
		a.job = i;
		a.job_t = a.clock;
	case =>
		say(a, "Kunne ikke starte spillet.");
	};
};

fn install(a: *app, i: size) void = {
	let buf: [4096]u8 = [0...];
	let script = "";
	if (i == ALL) {
		// Everything that's missing, one after the other.
		let n = 0z;
		for (let k = 0z; k < len(GAMES); k += 1) {
			if (a.ready[k]) continue;
			let one: [1024]u8 = [0...];
			const s = fmt::bsprintf(buf[n..], "echo '[{}/22] {}'; {}; ", k + 1,
				GAMES[k].full, install_script(one, k))!;
			n += len(s);
		};
		if (n == 0) {
			say(a, "Alle 22 spil er allerede installeret!");
			return;
		};
		script = strings::fromutf8_unsafe(buf[..n]);
	} else {
		script = install_script(buf, i);
	};
	match (run_logged(script, a.log)) {
	case let p: exec::process =>
		a.proc = p;
		a.mode = mode::INSTALLING;
		a.job = i;
		a.job_t = a.clock;
	case =>
		say(a, "Kunne ikke starte installationen.");
	};
};

// Checks whether the game or the installation has finished.
fn poll(a: *app) void = {
	if (a.mode == mode::BROWSE) return;
	match (exec::peek(&a.proc)) {
	case void => return;
	case => void;
	};
	const was = a.mode;
	a.mode = mode::BROWSE;
	let buf: [160]u8 = [0...];
	if (was == mode::PLAYING) {
		// A game that closes right away usually has something to say.
		const m = croc_message(buf, a.log);
		if (len(m) > 0) say(a, m)
		else if (a.clock - a.job_t < 3.0) say(a, "Spillet lukkede med det samme.");
		return;
	};
	scan(&a.ready);
	let mb: [160]u8 = [0...];
	if (a.job == ALL) {
		say(a, fmt::bsprintf(mb, "Færdig! {} af 22 spil er klar.", nready(a))!);
	} else if (a.ready[a.job]) {
		say(a, fmt::bsprintf(mb, "{} er installeret. Tryk Enter for at spille!",
			GAMES[a.job].full)!);
	} else {
		const m = croc_message(buf, a.log);
		say(a, if (len(m) > 0) m else "Installationen lykkedes ikke. Se loggen i /tmp.");
	};
};

fn card_at(mx: int, my: int) (size | void) = {
	for (let i = 0z; i < len(GAMES); i += 1) {
		const (x, y) = card_pos(i);
		if (mx >= x && mx < x + CW && my >= y && my < y + CH) return i;
	};
};

fn card_pos(i: size) (int, int) =
	(GX + (i % COLS): int * (CW + GAP), GY + (i / COLS): int * (CH + GAP));

export fn main() void = {
	const win = match (viper::open("Croc Arcade", W, H)) {
	case let w: *viper::window => yield w;
	case let e: viper::error => fmt::fatal("hpo croc:", viper::strerror(e));
	case nomem => fmt::fatal("hpo croc: out of memory");
	};
	defer viper::close(win);
	let a = app { bg = make_bg(), ... };
	a.log = tmpfile(a.logbuf, "log");
	scan(&a.ready);
	match (viper::load_png("/usr/local/share/hpo/hpo-croc-64.png")) {
	case let icon: viper::image =>
		viper::set_icon(win, &icon);
		viper::image_free(&icon);
	case viper::imgerror => void;
	};

	for (viper::frame(win)) {
		const dt = viper::delta(win);
		a.clock += dt;
		if (a.msg_t > 0.0) a.msg_t -= dt;
		poll(&a);
		if (a.mode == mode::BROWSE && input(win, &a)) break;
		draw(win, &a);
		viper::present(win);
	};
};

// Keys and mouse while browsing. Returns true to quit.
fn input(win: *viper::window, a: *app) bool = {
	if (viper::key_pressed(win, viper::key::ESCAPE)) return true;
	const n = len(GAMES);
	if (viper::key_pressed(win, viper::key::RIGHT)) a.sel = (a.sel + 1) % n;
	if (viper::key_pressed(win, viper::key::LEFT)) a.sel = (a.sel + n - 1) % n;
	if (viper::key_pressed(win, viper::key::DOWN)) a.sel = (a.sel + COLS) % n;
	if (viper::key_pressed(win, viper::key::UP)) a.sel = (a.sel + n - COLS) % n;
	if (viper::key_pressed(win, viper::key::RETURN) || viper::key_pressed(win, viper::key::KP_ENTER)
			|| viper::key_pressed(win, viper::key::SPACE)) {
		play(a, a.sel);
		return false;
	};
	if (viper::key_pressed(win, viper::key::I)) install(a, a.sel);
	if (viper::key_pressed(win, viper::key::A)) install(a, ALL);
	if (viper::key_pressed(win, viper::key::R)) {
		scan(&a.ready);
		let b: [64]u8 = [0...];
		say(a, fmt::bsprintf(b, "{} af 22 spil er klar.", nready(a))!);
	};
	const (mx, my) = viper::mouse(win);
	match (card_at(mx, my)) {
	case let i: size =>
		a.sel = i;
		if (viper::mouse_pressed(win)) play(a, i);
	case void => void;
	};
	return false;
};

// ---- Drawing ----

def C_BG: u32 = 0xff0f2214;
def C_CARD: u32 = 0xff17331f;
def C_GOLD: u32 = 0xffffc83a;
def C_RED: u32 = 0xffb02a2a;
def C_TEXT: u32 = 0xfff2ecd8;
def C_DIM: u32 = 0xff8aa890;

// Dark green with a pattern of crocodile scales, made once.
fn make_bg() viper::image = {
	let px: []u32 = alloc([C_BG...], (W * H): size)!;
	for (let y = 0; y < H; y += 1) for (let x = 0; x < W; x += 1) {
		const row = y / 18;
		const sx = (x + (row % 2) * 14) % 28 - 14, sy = y % 18 - 9;
		const d = sx * sx * 9 / 4 + sy * sy * 4;
		if (d > 280 && d < 360) px[(y * W + x): size] = 0xff132a19;
	};
	return viper::image { w = W, h = H, pixels = px };
};


fn shade(win: *viper::window, x: int, y: int, w: int, h: int, col: u32, a: u32) void = {
	for (let yy = y; yy < y + h; yy += 1) {
		if (yy < 0 || yy >= win.height) continue;
		for (let xx = x; xx < x + w; xx += 1) {
			if (xx < 0 || xx >= win.width) continue;
			let p = &win.pixels[(yy * win.width + xx): size];
			const r = ((*p >> 16) & 0xff) * (255 - a) + ((col >> 16) & 0xff) * a;
			const g = ((*p >> 8) & 0xff) * (255 - a) + ((col >> 8) & 0xff) * a;
			const b = (*p & 0xff) * (255 - a) + (col & 0xff) * a;
			*p = 0xff000000 | (r / 255) << 16 | (g / 255) << 8 | b / 255;
		};
	};
};

fn centered(win: *viper::window, cx: int, y: int, s: str, col: u32, scale: int) void =
	viper::text_scaled(win, cx - viper::text_width(s, scale) / 2, y, s, col, scale);

fn draw(win: *viper::window, a: *app) void = {
	viper::draw_image(win, &a.bg, 0, 0);
	draw_marquee(win, a);
	for (let i = 0z; i < len(GAMES); i += 1) draw_card(win, a, i);
	draw_info(win, a);
	switch (a.mode) {
	case mode::PLAYING => draw_busy(win, a, "TILT!", "Spiller", "Luk spillet for at komme tilbage til arkaden.");
	case mode::INSTALLING => draw_busy(win, a, "INSTALLERER", "Henter", "");
	case mode::BROWSE => void;
	};
};

fn draw_marquee(win: *viper::window, a: *app) void = {
	viper::round_rect(win, 20, 12, W - 40, 92, 18, C_GOLD);
	viper::round_rect(win, 26, 18, W - 52, 80, 14, C_RED);
	// Running lights round the sign.
	for (let i = 0; i < 46; i += 1) {
		const on = (i + (a.clock * 8.0): int) % 3 == 0;
		const col: u32 = if (on) 0xfffff2a0 else 0xff8a5a1a;
		viper::circle(win, 40 + i * 20, 22, 3, col);
		viper::circle(win, 40 + i * 20, 94, 3, col);
	};
	draw_croc(win, 100.0, 60.0, 1.1, a.clock);
	viper::text_scaled(win, 213, 29, "CROC ARCADE", 0xff4a0a0a, 3);
	viper::text_scaled(win, 210, 26, "CROC ARCADE", C_GOLD, 3);
	viper::text(win, 212, 74, "hpo  -  Retro Arcade Hub  -  Master Croc", 0xffffe0b0);
	let b: [32]u8 = [0...];
	const s = fmt::bsprintf(b, "{}/22 klar", nready(a))!;
	viper::text_scaled(win, W - 60 - viper::text_width(s, 2), 44, s, 0xfffff2d8, 2);
};

fn draw_card(win: *viper::window, a: *app, i: size) void = {
	const g = &GAMES[i];
	const (x, y) = card_pos(i);
	const sel = i == a.sel && a.mode == mode::BROWSE;
	if (sel) {
		const glow = 3 + (math::sinf64(a.clock * 6.0) * 1.5): int;
		viper::round_rect(win, x - glow, y - glow, CW + glow * 2, CH + glow * 2, 16, C_GOLD);
	};
	viper::round_rect(win, x, y, CW, CH, 14, if (sel) 0xff24502e else C_CARD);
	viper::round_rect(win, x, y, CW, 8, 4, g.col);
	// The picture, bobbing when picked.
	const bob = if (sel) math::sinf64(a.clock * 4.0) * 4.0 else 0.0;
	viper::circle(win, x + CW / 2, y + 56, 40, 0xff0f2214);
	draw_icon(win, g.icon, (x + CW / 2): f64, y: f64 + 56.0 + bob, if (sel) a.clock else 0.0);
	if (!a.ready[i]) shade(win, x + 8, y + 12, CW - 16, 90, 0x0f2214, 110);
	centered(win, x + CW / 2, y + 104, g.name, C_TEXT, 1);
	// Ready or not.
	const chip = if (a.ready[i]) "KLAR" else "INSTALLER";
	const cw = viper::text_width(chip, 1) + 16;
	viper::round_rect(win, x + (CW - cw) / 2, y + 124, cw, 18, 9,
		if (a.ready[i]) 0xff2a8a3a else 0xff4a4a40);
	centered(win, x + CW / 2, y + 125, chip, if (a.ready[i]) 0xffe0ffe0 else 0xffd8d0b8, 1);
};

fn draw_info(win: *viper::window, a: *app) void = {
	const y = 594;
	viper::round_rect(win, 20, y, W - 40, 74, 14, 0xff0a1a0e);
	if (a.msg_t > 0.0) {
		// A message from the arcade.
		draw_croc(win, 70.0, (y + 38): f64, 0.6, a.clock);
		viper::text_scaled(win, 110, y + 22, a.msg, C_GOLD, if (viper::text_width(a.msg, 2) < W - 160) 2 else 1);
		return;
	};
	const g = &GAMES[a.sel];
	viper::text_scaled(win, 36, y + 10, g.full, C_TEXT, 2);
	viper::text(win, 36 + viper::text_width(g.full, 2) + 14, y + 18, g.genre, C_GOLD);
	viper::text(win, 36, y + 46, g.about, C_DIM);
	// Buttons.
	let bx = W - 40;
	const third = " Opdater (R) ";
	bx -= viper::text_width(third, 1) + 24;
	if (viper::button(win, third, bx, y + 22) && a.mode == mode::BROWSE) {
		scan(&a.ready);
	};
	const second = " Installér alle (A) ";
	bx -= viper::text_width(second, 1) + 24 + 10;
	if (viper::button(win, second, bx, y + 22) && a.mode == mode::BROWSE) install(a, ALL);
	const first = if (a.ready[a.sel]) " Spil (Enter) " else " Installér (I) ";
	bx -= viper::text_width(first, 1) + 24 + 10;
	if (viper::button(win, first, bx, y + 22) && a.mode == mode::BROWSE) play(a, a.sel);
};

// While a game runs or something installs.
fn draw_busy(win: *viper::window, a: *app, title: str, verb: str, hint: str) void = {
	shade(win, 0, 110, W, H - 110, 0x050d07, 170);
	const bw = 640, bh = 230, bx = (W - bw) / 2, by = 210;
	viper::round_rect(win, bx - 4, by - 4, bw + 8, bh + 8, 22, C_GOLD);
	viper::round_rect(win, bx, by, bw, bh, 18, 0xff17331f);
	// The croc chomps away while we wait.
	draw_croc(win, (bx + 110): f64, (by + 110): f64, 1.6, a.clock * 2.0);
	viper::text_scaled(win, bx + 220, by + 30, title, C_GOLD, 4);
	let b: [128]u8 = [0...];
	const what = if (a.job == ALL) "alle spil som mangler" else GAMES[a.job].full;
	viper::text_scaled(win, bx + 220, by + 100, fmt::bsprintf(b, "{} {}", verb, what)!, C_TEXT, 1);
	const secs = (a.clock - a.job_t): int;
	let tb: [32]u8 = [0...];
	viper::text(win, bx + 220, by + 124, fmt::bsprintf(tb, "{}:{}{}", secs / 60, if (secs % 60 < 10) "0" else "", secs % 60)!, C_DIM);
	if (a.mode == mode::INSTALLING) {
		// What the installer says right now.
		let lb: [128]u8 = [0...];
		const line = last_line(lb, a.log);
		let shown = line;
		if (viper::text_width(shown, 1) > bw - 40) {
			const b2 = strings::toutf8(shown);
			let n = ((bw - 40) / 8): size;
			for (n > 0 && n < len(b2) && b2[n] & 0xc0 == 0x80) n -= 1;
			shown = strings::fromutf8_unsafe(b2[..n]);
		};
		viper::text(win, bx + 20, by + 190, shown, C_DIM);
		// A bouncing progress bar.
		const p = math::modf64(a.clock * 0.6, 1.0);
		viper::round_rect(win, bx + 220, by + 150, 380, 12, 6, 0xff0a1a0e);
		viper::round_rect(win, bx + 220 + (p * 300.0): int, by + 150, 80, 12, 6, C_GOLD);
	} else {
		viper::text(win, bx + 220, by + 160, hint, C_DIM);
	};
};
