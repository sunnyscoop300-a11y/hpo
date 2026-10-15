// antelope -- Antelope Warrior (den unavngivne antilope fra Dragon Warrior-turneringen
// i Kung Fu Panda 4): MakeMKV + HandBrake disc ripper, integrated into hpo.
// Port af MkvMaker.java. All declarations are prefixed aw_/AW_ to avoid
// clashes with hpo's existing symbols in the same package.
//
// Antelope Warrior - Hare-styring af MakeMKV (makemkvcon) og HandBrake (HandBrakeCLI)
// Port af MkvMaker.java. Ingen JVM: en enkelt native binaer, der styrer
// makemkvcon / HandBrakeCLI / ffprobe som underprocesser.
//
// MP4-regler:
//   dansk tale findes          -> kun dansk tale, ingen undertekster
//   udenlandsk + danske subs   -> originaltale + danske undertekster braendt ind
//   udenlandsk, ingen danske   -> engelsk tale, ingen undertekster
//
// Del af hpo: kaldes via `hpo antelope` (do_antelope).
use bufio;
use fmt;
use fs;
use io;
use os;
use os::exec;
use strconv;
use strings;
use time;

def AW_RESET = "\x1b[0m";
def AW_BOLD = "\x1b[1m";
def AW_CYAN = "\x1b[96m";
def AW_GOLD = "\x1b[33m";
def AW_IRON = "\x1b[90m";
def AW_RED = "\x1b[91m";
def AW_GREEN = "\x1b[92m";

def AW_PRESET = "HQ 1080p30 Surround";
def AW_HB_LOG = "/tmp/antelope-warrior-handbrake.log";
def AW_BARW: size = 30;

// MakeMKV attribut-id'er (apdefs.h)
def AW_A_NAME = 2;
def AW_A_CHAPTERS = 8;
def AW_A_DURATION = 9;
def AW_A_SIZE = 10;
def AW_A_FILE = 27;

let aw_makemkvcon: str = "makemkvcon";
let aw_outdir: str = "";
let aw_home: str = "";
let aw_handbrake: []str = [];

// ================= Robot-linjer =================

type aw_drive = struct {
	index: int,
	drivename: str,
	discname: str,
	device: str,
};
type aw_titleinfo = struct {
	aw_title: int,
	attr: int,
	value: str,
};
type aw_progress = struct {
	current: u64,
	total: u64,
	max: u64,
};
type aw_progtitle = struct {
	current: bool,
	name: str,
};
type aw_msg = struct {
	text: str,
};
// void = linjen er ikke interessant
type aw_line = (aw_drive | aw_titleinfo | aw_progress | aw_progtitle | aw_msg | void);

// Felterne efter "TAG:" som CSV. Tom liste hvis der ikke er noget kolon.
fn aw_fields(raw: str) []str = {
	match (strings::byteindex(raw, ':')) {
	case let i: size =>
		return aw_csv(aw_bsub(raw, i + 1, len(raw)));
	case void =>
		let empty: []str = [];
		return empty;
	};
};

// Strengene i den returnerede linje laaner fra 'f' - kopier dem hvis de skal gemmes.
fn aw_parse(raw: str, f: []str) aw_line = {
	const colon = match (strings::byteindex(raw, ':')) {
	case let i: size =>
		yield i;
	case void =>
		return void;
	};
	const tag = aw_bsub(raw, 0, colon);
	switch (tag) {
	case "DRV" =>
		if (len(f) < 7) return void;
		const i = match (aw_atoi(f[0])) {
		case let i: int =>
			yield i;
		case void =>
			return void;
		};
		return aw_drive { index = i, drivename = f[4], discname = f[5], device = f[6] };
	case "TINFO" =>
		if (len(f) < 4) return void;
		const t = match (aw_atoi(f[0])) {
		case let i: int =>
			yield i;
		case void =>
			return void;
		};
		const a = match (aw_atoi(f[1])) {
		case let i: int =>
			yield i;
		case void =>
			return void;
		};
		return aw_titleinfo { aw_title = t, attr = a, value = f[3] };
	case "PRGV" =>
		if (len(f) < 3) return void;
		const c = match (aw_atou64(f[0])) {
		case let n: u64 =>
			yield n;
		case void =>
			return void;
		};
		const t = match (aw_atou64(f[1])) {
		case let n: u64 =>
			yield n;
		case void =>
			return void;
		};
		const m = match (aw_atou64(f[2])) {
		case let n: u64 =>
			yield n;
		case void =>
			return void;
		};
		return aw_progress { current = c, total = t, max = m };
	case "PRGT" =>
		if (len(f) < 3) return void;
		return aw_progtitle { current = false, name = f[2] };
	case "PRGC" =>
		if (len(f) < 3) return void;
		return aw_progtitle { current = true, name = f[2] };
	case "MSG" =>
		return aw_msg { text = if (len(f) > 3) f[3] else raw };
	case =>
		return void;
	};
};

// Robot-output er CSV med citerede felter, der selv kan indeholde kommaer.
fn aw_csv(s: str) []str = {
	let out: []str = [];
	let cur: []u8 = [];
	defer free(cur);
	const b = strings::toutf8(s);
	let q = false;
	for (let i = 0z; i < len(b); i += 1) {
		const c = b[i];
		if (c == 34) { // "
			if (q && i + 1 < len(b) && b[i + 1] == 34) {
				append(cur, 34u8)!;
				i += 1;
			} else {
				q = !q;
			};
		} else if (c == 44 && !q) { // ,
			append(out, strings::dup(strings::fromutf8_unsafe(cur))!)!;
			delete(cur[..]);
		} else {
			append(cur, c)!;
		};
	};
	append(out, strings::dup(strings::fromutf8_unsafe(cur))!)!;
	return out;
};

// ================= Model =================

type aw_title = struct {
	id: int,
	name: str,
	duration: str,
	sz: str,
	file: str,
	chapters: int,
};

type aw_titlectx = struct {
	list: []aw_title,
};

type aw_drivectx = struct {
	list: []aw_drive,
};

type aw_ripctx = struct {
	task: str,
};

// ================= Main =================

fn do_antelope(o: *opts) void = {
	aw_home = match (os::getenv("HOME")) {
	case let h: str =>
		yield h;
	case void =>
		yield "/root";
	};
	aw_outdir = strings::concat(aw_home, "/Videos/mkvmaker")!;

	match (aw_which("makemkvcon")) {
	case let p: str =>
		aw_makemkvcon = p;
	case void =>
		aw_banner();
		fmt::printfln("{}  makemkvcon blev ikke fundet i PATH.{}", AW_RED, AW_RESET)!;
		return;
	};
	aw_banner();

	for (true) {
		fmt::printfln("{}\n  [1] scan drev   [2] vis titler   [3] rip titel   [4] rip alle   [5] lav mp4   [o] output-mappe   [q] afslut{}",
			AW_GOLD, AW_RESET)!;
		fmt::printf("{}  ✦ › {}", AW_CYAN, AW_RESET)!;
		bufio::flush(os::stdout)!;
		const c = match (aw_readline()) {
		case let s: str =>
			yield strings::trim(s);
		case void =>
			break;
		};
		switch (c) {
		case "1" =>
			aw_scandrives();
		case "2" =>
			match (aw_askint("disk-nummer")) {
			case let d: int =>
				aw_showtitles(d);
			case void => void;
			};
		case "3" =>
			match (aw_askint("disk-nummer")) {
			case let d: int =>
				match (aw_askint("titel-nummer")) {
				case let t: int =>
					const ts = strings::dup(strconv::itos(t))!;
					defer free(ts);
					aw_rip(d, ts);
				case void => void;
				};
			case void => void;
			};
		case "4" =>
			match (aw_askint("disk-nummer")) {
			case let d: int =>
				aw_rip(d, "all");
			case void => void;
			};
		case "5" =>
			aw_convert();
		case "o" =>
			fmt::printf("{}  ny mappe ({}): {}", AW_IRON, aw_outdir, AW_RESET)!;
			bufio::flush(os::stdout)!;
			match (aw_readline()) {
			case let s: str =>
				const p = strings::trim(s);
				if (len(p) > 0) {
					aw_outdir = if (strings::hasprefix(p, "~"))
						strings::concat(aw_home, aw_bsub(p, 1, len(p)))!
					else
						strings::dup(p)!;
				};
			case void => void;
			};
			fmt::printfln("  output: {}", aw_outdir)!;
		case "q", "quit", "exit" =>
			fmt::printfln("{}\n  Antilopen forlader Palace Arena. Turneringen fortsaetter en anden dag.{}", AW_IRON, AW_RESET)!;
			return;
		case =>
			fmt::printfln("{}  ukendt valg{}", AW_IRON, AW_RESET)!;
		};
	};
};

// ================= Kommandoer =================

fn aw_on_drive(ctx: *opaque, raw: str) void = {
	let d = ctx: *aw_drivectx;
	const f = aw_fields(raw);
	defer strings::freeall(f);
	match (aw_parse(raw, f)) {
	case let dr: aw_drive =>
		if (len(strings::trim(dr.drivename)) == 0) return;
		append(d.list, aw_drive {
			index = dr.index,
			drivename = strings::dup(dr.drivename)!,
			discname = strings::dup(dr.discname)!,
			device = strings::dup(dr.device)!,
		})!;
	case => void;
	};
};

fn aw_scandrives() void = {
	fmt::printfln("{}  antilopen spejder ud over arenaen efter drev...{}", AW_IRON, AW_RESET)!;
	let dc = aw_drivectx { list = [] };
	aw_run([aw_makemkvcon, "-r", "--cache=1", "info", "disc:9999"], true, void, &aw_on_drive, &dc);
	if (len(dc.list) == 0) {
		fmt::println("  ingen drev i arenaen")!;
		return;
	};
	for (let i = 0z; i < len(dc.list); i += 1) {
		const d = dc.list[i];
		fmt::printf("  {}[{}]{} ", AW_GOLD, d.index, AW_RESET)!;
		aw_putpad(d.drivename, 52);
		fmt::print(" ")!;
		if (len(strings::trim(d.discname)) == 0) {
			fmt::printf("{}(ingen disk){}", AW_IRON, AW_RESET)!;
		} else {
			fmt::printf("{}{}{}", AW_CYAN, d.discname, AW_RESET)!;
		};
		fmt::printfln("  {}{}{}", AW_IRON, d.device, AW_RESET)!;
	};
};

fn aw_gettitle(tc: *aw_titlectx, id: int) *aw_title = {
	for (let i = 0z; i < len(tc.list); i += 1) {
		if (tc.list[i].id == id) return &tc.list[i];
	};
	append(tc.list, aw_title {
		id = id,
		name = "",
		duration = "?",
		sz = "?",
		file = "",
		chapters = 0,
	})!;
	return &tc.list[len(tc.list) - 1];
};

fn aw_on_title(ctx: *opaque, raw: str) void = {
	let tc = ctx: *aw_titlectx;
	const f = aw_fields(raw);
	defer strings::freeall(f);
	match (aw_parse(raw, f)) {
	case let ti: aw_titleinfo =>
		let t = aw_gettitle(tc, ti.aw_title);
		switch (ti.attr) {
		case AW_A_NAME =>
			t.name = strings::dup(ti.value)!;
		case AW_A_DURATION =>
			t.duration = strings::dup(ti.value)!;
		case AW_A_SIZE =>
			t.sz = strings::dup(ti.value)!;
		case AW_A_FILE =>
			t.file = strings::dup(ti.value)!;
		case AW_A_CHAPTERS =>
			match (aw_atoi(ti.value)) {
			case let n: int =>
				t.chapters = n;
			case void => void;
			};
		case => void;
		};
	case => void;
	};
};

fn aw_showtitles(disc: int) void = {
	fmt::printfln("{}  antilopen studerer modstanderen paa disk {} (det kan tage et minut)...{}", AW_IRON, disc, AW_RESET)!;
	let tc = aw_titlectx { list = [] };
	const arg = fmt::asprintf("disc:{}", disc)!;
	defer free(arg);
	aw_run([aw_makemkvcon, "-r", "info", arg], true, void, &aw_on_title, &tc);
	if (len(tc.list) == 0) {
		fmt::printfln("  ingen titler - er der en disk i drev {}?", disc)!;
		return;
	};
	fmt::println()!;
	fmt::print("  ", AW_IRON)!;
	aw_putpad("#", 5);
	aw_putpad("varighed", 11);
	aw_putpad("stoerrelse", 11);
	aw_putpad("kap.", 6);
	fmt::printfln("fil{}", AW_RESET)!;
	for (let i = 0z; i < len(tc.list); i += 1) {
		const t = tc.list[i];
		fmt::printf("  {}", AW_GOLD)!;
		aw_putpad(strconv::itos(t.id), 5);
		fmt::print(AW_RESET)!;
		aw_putpad(t.duration, 11);
		aw_putpad(t.sz, 11);
		aw_putpad(strconv::itos(t.chapters), 6);
		fmt::println(if (len(t.file) == 0) t.name else t.file)!;
	};
};

fn aw_on_rip(ctx: *opaque, raw: str) void = {
	let rc = ctx: *aw_ripctx;
	const f = aw_fields(raw);
	defer strings::freeall(f);
	match (aw_parse(raw, f)) {
	case let pt: aw_progtitle =>
		if (pt.current) rc.task = strings::dup(pt.name)!;
	case let p: aw_progress =>
		if (p.max == 0) return;
		let tenths = p.total * 1000 / p.max;
		if (tenths > 1000) tenths = 1000;
		fmt::print("\r  ")!;
		aw_drawbar(tenths);
		fmt::print("  ")!;
		aw_putpad(aw_trunc(rc.task, 28), 28);
		bufio::flush(os::stdout)!;
	case let m: aw_msg =>
		const low = aw_lower(m.text);
		defer free(low);
		if (strings::contains(low, "error")) {
			fmt::printfln("\n  {}{}{}", AW_RED, m.text, AW_RESET)!;
		};
	case => void;
	};
};

fn aw_rip(disc: int, aw_title: str) void = {
	match (os::mkdirs(aw_outdir, 0o755)) {
	case void => void;
	case let e: fs::error =>
		fmt::printfln("{}  kan ikke oprette {}: {}{}", AW_RED, aw_outdir, fs::strerror(e), AW_RESET)!;
		return;
	};
	fmt::printfln("{}  antilopen traeder ind i Palace Arena: disk {}, titel {} -> {}{}", AW_IRON, disc, aw_title, aw_outdir, AW_RESET)!;

	const t0 = time::now(time::clock::MONOTONIC);
	let rc = aw_ripctx { task = "" };
	const arg = fmt::asprintf("disc:{}", disc)!;
	defer free(arg);
	const exit = aw_run([aw_makemkvcon, "-r", "--progress=-same", "mkv", arg, aw_title, aw_outdir],
		true, void, &aw_on_rip, &rc);
	fmt::println()!;
	const secs = time::diff(t0, time::now(time::clock::MONOTONIC)) / time::SECOND;
	if (exit == 0) {
		fmt::printfln("  {}kampen er vundet{} paa {} s", AW_GREEN, AW_RESET, secs: i64)!;
		fmt::printfln("{}  [5] naeste runde: lav en mp4 ud af den{}", AW_IRON, AW_RESET)!;
	} else {
		fmt::printfln("  {}antilopen blev slaaet ud af arenaen (makemkvcon kode {}){}", AW_RED, exit, AW_RESET)!;
	};
};

// ================= HandBrake / MP4 =================

type aw_track = struct {
	num: int,
	lang: str,
	desc: str,
};

type aw_plan = struct {
	audio: aw_track,
	sub: (aw_track | void),
	reason: str,
};

type aw_scanctx = struct {
	section: int, // 0 = andet, 1 = lyd, 2 = undertekster
	audio: []aw_track,
	subs: []aw_track,
};

type aw_collectctx = struct {
	lines: []str,
};

// Naar HandBrake ikke skriver ISO-koden, gaettes sproget ud fra navnet.
const AW_NAMES: [_](str, str) = [
	("dansk", "dan"), ("danish", "dan"),
	("english", "eng"), ("engelsk", "eng"),
	("deutsch", "deu"), ("german", "deu"),
	("español", "spa"), ("espanol", "spa"), ("spanish", "spa"),
	("svenska", "swe"), ("swedish", "swe"),
	("norsk", "nor"), ("norwegian", "nor"),
	("suomi", "fin"), ("finnish", "fin"),
	("íslenska", "isl"), ("Íslenska", "isl"), ("icelandic", "isl"),
	("français", "fra"), ("francais", "fra"), ("french", "fra"),
	("italiano", "ita"), ("italian", "ita"),
	("japanese", "jpn"), ("日本語", "jpn"),
];

fn aw_findhandbrake() bool = {
	match (aw_which("HandBrakeCLI")) {
	case let p: str =>
		append(aw_handbrake, p)!;
		return true;
	case void => void;
	};
	// Flatpak-udgaven af HandBrake har CLI'en med indbygget
	if (aw_quietok(["flatpak", "info", "fr.handbrake.ghb"])) {
		append(aw_handbrake, "flatpak")!;
		append(aw_handbrake, "run")!;
		append(aw_handbrake, "--command=HandBrakeCLI")!;
		append(aw_handbrake, "fr.handbrake.ghb")!;
		return true;
	};
	return false;
};

fn aw_convert() void = {
	if (len(aw_handbrake) == 0 && !aw_findhandbrake()) {
		fmt::printfln("{}  HandBrakeCLI blev ikke fundet.{}", AW_RED, AW_RESET)!;
		fmt::printfln("{}  sudo apt install handbrake-cli{}", AW_IRON, AW_RESET)!;
		return;
	};
	if (!aw_isdir(aw_outdir)) {
		fmt::printfln("  output-mappen findes ikke: {}", aw_outdir)!;
		return;
	};

	const ents = match (os::readdir(aw_outdir)) {
	case let e: []fs::dirent =>
		yield e;
	case =>
		fmt::printfln("{}  kan ikke laese {}{}", AW_RED, aw_outdir, AW_RESET)!;
		return;
	};
	defer fs::dirents_free(ents);

	let mkvs: []str = [];
	for (let i = 0z; i < len(ents); i += 1) {
		const low = aw_lower(ents[i].name);
		defer free(low);
		if (strings::hassuffix(low, ".mkv")) append(mkvs, ents[i].name)!;
	};
	defer free(mkvs);
	if (len(mkvs) == 0) {
		fmt::printfln("  ingen .mkv-filer i {}", aw_outdir)!;
		return;
	};
	aw_sortstrs(mkvs);

	fmt::println()!;
	for (let i = 0z; i < len(mkvs); i += 1) {
		const full = strings::concat(aw_outdir, "/", mkvs[i])!;
		defer free(full);
		fmt::printf("  {}[{}]{} ", AW_GOLD, i, AW_RESET)!;
		aw_putpad(mkvs[i], 40);
		fmt::printf(" {}", AW_IRON)!;
		aw_puthuman(aw_filesize(full));
		fmt::println(AW_RESET)!;
	};
	const pick = match (aw_askint("fil-nummer")) {
	case let p: int =>
		yield p;
	case void =>
		return;
	};
	if (pick < 0 || pick: size >= len(mkvs)) return;

	const src = strings::concat(aw_outdir, "/", mkvs[pick: size])!;
	defer free(src);
	const dst = strings::concat(aw_bsub(src, 0, len(src) - 4), ".mp4")!;
	defer free(dst);

	fmt::printfln("{}  antilopen tjekker modstanderens spor...{}", AW_IRON, AW_RESET)!;
	let sc = aw_scanctx { section = 0, audio = [], subs = [] };
	aw_scan(src, &sc);
	if (len(sc.audio) == 0) {
		fmt::printfln("{}  fandt ingen lydspor - kan HandBrake laese filen?{}", AW_RED, AW_RESET)!;
		return;
	};

	fmt::printfln("{}\n  lyd{}", AW_GOLD, AW_RESET)!;
	for (let i = 0z; i < len(sc.audio); i += 1) {
		const t = sc.audio[i];
		fmt::printfln("   {}  {}  {}{}{}", t.num, t.lang, AW_IRON, t.desc, AW_RESET)!;
	};
	fmt::printfln("{}  undertekster{}", AW_GOLD, AW_RESET)!;
	if (len(sc.subs) == 0) fmt::printfln("{}   (ingen){}", AW_IRON, AW_RESET)!;
	for (let i = 0z; i < len(sc.subs); i += 1) {
		const t = sc.subs[i];
		fmt::printfln("   {}  {}  {}{}{}", t.num, t.lang, AW_IRON, t.desc, AW_RESET)!;
	};

	const p = aw_decide(sc.audio, sc.subs);
	fmt::printfln("{}\n  kampplan: {}{}", AW_CYAN, AW_RESET, p.reason)!;
	fmt::printfln("   tale:        spor {} ({})", p.audio.num, p.audio.lang)!;
	match (p.sub) {
	case let s: aw_track =>
		fmt::printfln("   undertekst:  spor {} (dan), braendt ind", s.num)!;
	case void =>
		fmt::println("   undertekst:  ingen")!;
	};
	fmt::printfln("   preset:      {}", AW_PRESET)!;
	fmt::printfln("   ud:          {}", dst)!;
	if (os::exists(dst)) {
		fmt::printfln("{}   (filen findes og bliver overskrevet){}", AW_GOLD, AW_RESET)!;
	};

	fmt::printf("{}  ind i arenaen? (j/n): {}", AW_IRON, AW_RESET)!;
	bufio::flush(os::stdout)!;
	const ok = match (aw_readline()) {
	case let s: str =>
		yield aw_lower(strings::trim(s));
	case void =>
		return;
	};
	if (!strings::hasprefix(ok, "j")) return;

	const anum = fmt::asprintf("{}", p.audio.num)!;
	defer free(anum);
	let cmd: []str = [];
	defer free(cmd);
	append(cmd, aw_handbrake...)!;
	append(cmd, "-i")!;
	append(cmd, src)!;
	append(cmd, "-o")!;
	append(cmd, dst)!;
	append(cmd, "--preset")!;
	append(cmd, AW_PRESET)!;
	append(cmd, "--optimize")!;
	append(cmd, "-a")!;
	append(cmd, anum)!;
	let snum = "";
	match (p.sub) {
	case let s: aw_track =>
		snum = fmt::asprintf("{}", s.num)!;
		append(cmd, "-s")!;
		append(cmd, snum)!;
		append(cmd, "--subtitle-burned=1")!;
	case void =>
		append(cmd, "-s")!;
		append(cmd, "none")!;
	};

	const t0 = time::now(time::clock::MONOTONIC);
	const exit = aw_encode(cmd);
	fmt::println()!;
	const mins = time::diff(t0, time::now(time::clock::MONOTONIC)) / (60 * time::SECOND);
	if (exit == 0 && os::exists(dst)) {
		fmt::printf("  {}runden er vundet{} paa {} min  ->  {} (", AW_GREEN, AW_RESET, mins: i64, aw_basename(dst))!;
		aw_puthuman(aw_filesize(dst));
		fmt::println(")")!;
	} else {
		fmt::printfln("  {}antilopen tabte runden (HandBrake kode {}){}", AW_RED, exit, AW_RESET)!;
	};
};

fn aw_decide(audio: []aw_track, subs: []aw_track) aw_plan = {
	for (let i = 0z; i < len(audio); i += 1) {
		if (audio[i].lang == "dan") {
			return aw_plan { audio = audio[i], sub = void,
				reason = "dansk tale fundet - ingen undertekster" };
		};
	};
	let tale = audio[0];
	for (let i = 0z; i < len(audio); i += 1) {
		if (audio[i].lang == "eng") {
			tale = audio[i];
			break;
		};
	};
	for (let i = 0z; i < len(subs); i += 1) {
		if (subs[i].lang == "dan") {
			return aw_plan { audio = tale, sub = subs[i],
				reason = "udenlandsk tale - danske undertekster braendes ind" };
		};
	};
	return aw_plan { audio = tale, sub = void,
		reason = "ingen danske undertekster - engelsk tale uden undertekster" };
};

// "+ 1, English (AC3) (5.1 ch) (iso639-2: eng)" -> track
fn aw_trackline(rest: str) (aw_track | void) = {
	const b = strings::toutf8(rest);
	const (num, i) = aw_digits(b, 0);
	if (i == 0 || !aw_at(b, i, ", ")) return;
	const r = aw_bsub(rest, i + 2, len(rest));
	let lang = "", desc = "";
	match (strings::byteindex(r, "(iso639-2: ")) {
	case let k: size =>
		const s = k + 11;
		if (s + 3 <= len(r) && aw_islower3(aw_bsub(r, s, s + 3))) {
			lang = strings::dup(aw_bsub(r, s, s + 3))!;
		} else {
			lang = aw_langfromname(r);
		};
		desc = strings::dup(strings::trim(aw_bsub(r, 0, k)))!;
	case void =>
		lang = aw_langfromname(r);
		desc = strings::dup(strings::trim(r))!;
	};
	return aw_track { num = num: int, lang = lang, desc = desc };
};

fn aw_on_scan(ctx: *opaque, raw: str) void = {
	let sc = ctx: *aw_scanctx;
	const l = strings::ltrim(raw);
	if (!strings::hasprefix(l, "+ ")) return;
	const rest = aw_bsub(l, 2, len(l));

	if (sc.section != 0) {
		match (aw_trackline(rest)) {
		case let t: aw_track =>
			if (sc.section == 1) append(sc.audio, t)! else append(sc.subs, t)!;
			return;
		case void => void;
		};
	};

	// sektion-overskrift: "+ audio tracks:" / "+ subtitle tracks:"
	match (strings::byteindex(rest, ':')) {
	case let i: size =>
		const h = aw_bsub(rest, 0, i);
		if (!aw_isheader(h)) return;
		sc.section = if (strings::hasprefix(h, "audio")) 1
			else if (strings::hasprefix(h, "subtitle")) 2
			else 0;
	case void => void;
	};
};

fn aw_scan(src: str, sc: *aw_scanctx) void = {
	let cmd: []str = [];
	defer free(cmd);
	append(cmd, aw_handbrake...)!;
	append(cmd, "-i")!;
	append(cmd, src)!;
	append(cmd, "--scan")!;
	aw_run(cmd, true, void, &aw_on_scan, sc);

	// ffprobe kender de rigtige ISO-koder; brug dem hvis antallet af spor stemmer
	aw_overridelangs(src, "a", sc.audio);
	aw_overridelangs(src, "s", sc.subs);
};

fn aw_langfromname(desc: str) str = {
	const b = strings::toutf8(strings::trim(desc));
	let end = 0z;
	for (end < len(b)) {
		const c = b[end];
		// mellemrum, tab, ( [ ,
		if (c == 32 || c == 9 || c == 40 || c == 91 || c == 44) break;
		end += 1;
	};
	const first = aw_lower(strings::fromutf8_unsafe(b[..end]));
	defer free(first);
	for (let i = 0z; i < len(AW_NAMES); i += 1) {
		if (AW_NAMES[i].0 == first) return AW_NAMES[i].1;
	};
	return "und";
};

fn aw_on_collect(ctx: *opaque, raw: str) void = {
	let cc = ctx: *aw_collectctx;
	append(cc.lines, strings::dup(strings::trim(raw))!)!;
};

fn aw_overridelangs(src: str, kind: str, tracks: []aw_track) void = {
	if (len(tracks) == 0) return;
	let cc = aw_collectctx { lines = [] };
	defer strings::freeall(cc.lines);
	const exit = aw_run(["ffprobe", "-v", "error", "-select_streams", kind,
		"-show_entries", "stream_tags=language", "-of", "csv=p=0", src],
		true, void, &aw_on_collect, &cc);
	// ingen ffprobe eller forkert antal - navnegaettet bliver staaende
	if (exit != 0 || len(cc.lines) != len(tracks)) return;
	for (let i = 0z; i < len(tracks); i += 1) {
		if (aw_islower3(cc.lines[i])) {
			tracks[i].lang = strings::dup(cc.lines[i])!;
		};
	};
};

// HandBrake skriver fremskridt med \r paa stdout og en stor log paa stderr.
// stderr gaar til HB_LOG; ved fejl vises de sidste 15 linjer.
fn aw_encode(cmd: []str) int = {
	const log = match (os::create(AW_HB_LOG, 0o644)) {
	case let f: io::file =>
		yield f;
	case =>
		fmt::printfln("{}  kan ikke oprette {}{}", AW_RED, AW_HB_LOG, AW_RESET)!;
		return -1;
	};
	let dummy = 0;
	const exit = aw_run(cmd, false, log, &aw_on_hb, &dummy);
	aw_closeq(log);
	if (exit != 0) {
		fmt::printfln("\n{}  sidste linjer fra HandBrake:{}", AW_IRON, AW_RESET)!;
		aw_tail(AW_HB_LOG, 15);
	};
	return exit;
};

// "Encoding: task 1 of 1, 12.34 % (45.6 fps, avg 50.0 fps, ETA 00h12m34s)"
fn aw_on_hb(ctx: *opaque, raw: str) void = {
	const k = match (strings::byteindex(raw, "task ")) {
	case let k: size =>
		yield k;
	case void =>
		return;
	};
	const b = strings::toutf8(raw);
	let i = k + 5;
	const (task, a) = aw_digits(b, i);
	if (a == i || !aw_at(b, a, " of ")) return;
	i = a + 4;
	const (of, c) = aw_digits(b, i);
	if (c == i || !aw_at(b, c, ", ")) return;
	i = c + 2;
	const (whole, d) = aw_digits(b, i);
	if (d == i) return;
	i = d;
	let tenth = 0u64;
	if (i < len(b) && b[i] == 46) { // .
		i += 1;
		if (i < len(b) && b[i] >= 48 && b[i] <= 57) tenth = (b[i] - 48): u64;
	};
	let t = whole * 10 + tenth;
	if (t > 1000) t = 1000;

	let eta = "";
	match (strings::byteindex(raw, "ETA ")) {
	case let e: size =>
		const s = e + 4;
		let j = s;
		for (j < len(b) && b[j] != 41) { // )
			j += 1;
		};
		eta = aw_bsub(raw, s, j);
	case void => void;
	};

	fmt::print("\r  ")!;
	aw_drawbar(t);
	fmt::printf("  {}", AW_IRON)!;
	if (len(eta) > 0) {
		const e = strings::concat("ETA ", eta)!;
		defer free(e);
		aw_putpad(e, 14);
	} else {
		aw_putpad("", 14);
	};
	fmt::print(AW_RESET)!;
	if (of > 1) fmt::printf(" ({}/{})", task, of)!;
	bufio::flush(os::stdout)!;
};

// ================= Proces =================

type aw_linefn = fn(ctx: *opaque, aw_line: str) void;

// Starter argv, sender hver linje af stdout (og stderr hvis merge) til cb.
// Returnerer exit-koden, eller -1 hvis programmet ikke kunne startes.
fn aw_run(argv: []str, merge: bool, errfile: (io::file | void), cb: *aw_linefn, ctx: *opaque) int = {
	bufio::flush(os::stdout)!;
	let cmd = match (exec::cmd(argv[0], argv[1..]...)) {
	case let c: exec::command =>
		yield c;
	case =>
		return -1;
	};
	const (rd, wr) = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, wr)!;
	if (merge) {
		exec::addfile(&cmd, os::stderr_file, wr)!;
	} else match (errfile) {
	case let f: io::file =>
		exec::addfile(&cmd, os::stderr_file, f)!;
	case void => void;
	};
	let proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		aw_closeq(rd);
		aw_closeq(wr);
		return -1;
	};
	aw_closeq(wr);
	aw_readloop(rd, cb, ctx);
	aw_closeq(rd);
	const st = match (exec::wait(&proc)) {
	case let s: exec::status =>
		yield s;
	case =>
		return -1;
	};
	match (exec::exit(&st)) {
	case let c: exec::exited =>
		return c: int;
	case =>
		return -1;
	};
};

// Deler output paa \n og \r (HandBrake/MakeMKV tegner fremskridt med \r).
fn aw_readloop(fd: io::file, cb: *aw_linefn, ctx: *opaque) void = {
	let buf: [4096]u8 = [0...];
	let cur: []u8 = [];
	defer free(cur);
	let lastcr = false;
	for (true) {
		const n = match (io::read(fd, buf[..])) {
		case let n: size =>
			yield n;
		case =>
			break;
		};
		for (let i = 0z; i < n; i += 1) {
			const c = buf[i];
			if (c == 10 && lastcr) {
				lastcr = false;
				continue;
			};
			lastcr = c == 13;
			if (c == 10 || c == 13) {
				cb(ctx, strings::fromutf8_unsafe(cur));
				delete(cur[..]);
			} else {
				append(cur, c)!;
			};
		};
	};
	if (len(cur) > 0) cb(ctx, strings::fromutf8_unsafe(cur));
};

fn aw_quietok(argv: []str) bool = {
	let cmd = match (exec::cmd(argv[0], argv[1..]...)) {
	case let c: exec::command =>
		yield c;
	case =>
		return false;
	};
	exec::addfile(&cmd, os::stdout_file, exec::nullfd)!;
	exec::addfile(&cmd, os::stderr_file, exec::nullfd)!;
	let proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		return false;
	};
	const st = match (exec::wait(&proc)) {
	case let s: exec::status =>
		yield s;
	case =>
		return false;
	};
	match (exec::exit(&st)) {
	case let c: exec::exited =>
		return (c: int) == 0;
	case =>
		return false;
	};
};

fn aw_which(name: str) (str | void) = {
	const path = match (os::getenv("PATH")) {
	case let p: str =>
		yield p;
	case void =>
		return;
	};
	const b = strings::toutf8(path);
	let start = 0z;
	for (let i = 0z; i <= len(b); i += 1) {
		if (i < len(b) && b[i] != 58) continue; // :
		const dir = strings::fromutf8_unsafe(b[start..i]);
		start = i + 1;
		if (len(dir) == 0) continue;
		const full = strings::concat(dir, "/", name)!;
		match (os::access(full, os::amode::X_OK)) {
		case let ok: bool =>
			if (ok) return full;
		case => void;
		};
		free(full);
	};
	return;
};

fn aw_closeq(f: io::file) void = {
	match (io::close(f)) {
	case void => void;
	case => void;
	};
};

// ================= Smaating =================

fn aw_readline() (str | void) = {
	match (bufio::read_line(os::stdin)) {
	case let b: []u8 =>
		return strings::fromutf8_unsafe(b);
	case =>
		return;
	};
};

fn aw_askint(what: str) (int | void) = {
	fmt::printf("{}  {}: {}", AW_IRON, what, AW_RESET)!;
	bufio::flush(os::stdout)!;
	const s = match (aw_readline()) {
	case let s: str =>
		yield s;
	case void =>
		return;
	};
	defer free(s);
	match (aw_atoi(strings::trim(s))) {
	case let i: int =>
		return i;
	case void =>
		fmt::printfln("{}  ikke et tal{}", AW_IRON, AW_RESET)!;
		return;
	};
};

fn aw_atoi(s: str) (int | void) = {
	match (strconv::stoi(s)) {
	case let i: int =>
		return i;
	case =>
		return;
	};
};

fn aw_atou64(s: str) (u64 | void) = {
	match (strconv::stou64(s)) {
	case let n: u64 =>
		return n;
	case =>
		return;
	};
};

// Byte-baseret delstreng (strings::sub bruger rune-indeks).
fn aw_bsub(s: str, a: size, b: size) str = {
	return strings::fromutf8_unsafe(strings::toutf8(s)[a..b]);
};

fn aw_digits(b: []u8, i: size) (u64, size) = {
	let n = 0u64;
	let j = i;
	for (j < len(b) && b[j] >= 48 && b[j] <= 57) {
		n = n * 10 + (b[j] - 48): u64;
		j += 1;
	};
	return (n, j);
};

fn aw_at(b: []u8, i: size, s: str) bool = {
	const sb = strings::toutf8(s);
	if (i + len(sb) > len(b)) return false;
	return strings::fromutf8_unsafe(b[i..i + len(sb)]) == s;
};

fn aw_lower(s: str) str = {
	let b: []u8 = [];
	append(b, strings::toutf8(s)...)!;
	for (let i = 0z; i < len(b); i += 1) {
		if (b[i] >= 65 && b[i] <= 90) b[i] += 32;
	};
	return strings::fromutf8_unsafe(b);
};

fn aw_islower3(s: str) bool = {
	const b = strings::toutf8(s);
	if (len(b) != 3) return false;
	for (let i = 0z; i < 3; i += 1) {
		if (b[i] < 97 || b[i] > 122) return false;
	};
	return true;
};

fn aw_isheader(h: str) bool = {
	const b = strings::toutf8(h);
	if (len(b) == 0) return false;
	for (let i = 0z; i < len(b); i += 1) {
		if (b[i] != 32 && (b[i] < 97 || b[i] > 122)) return false;
	};
	return true;
};

fn aw_runes(s: str) size = {
	const b = strings::toutf8(s);
	let n = 0z;
	for (let i = 0z; i < len(b); i += 1) {
		if ((b[i] & 0xc0) != 0x80) n += 1;
	};
	return n;
};

// De foerste n runer af s.
fn aw_trunc(s: str, n: size) str = {
	const b = strings::toutf8(s);
	let count = 0z;
	for (let i = 0z; i < len(b); i += 1) {
		if ((b[i] & 0xc0) != 0x80) {
			if (count == n) return strings::fromutf8_unsafe(b[..i]);
			count += 1;
		};
	};
	return s;
};

fn aw_putpad(s: str, w: size) void = {
	fmt::print(s)!;
	for (let i = aw_runes(s); i < w; i += 1) fmt::print(" ")!;
};

fn aw_rep(s: str, n: size) void = {
	for (let i = 0z; i < n; i += 1) fmt::print(s)!;
};

// tenths = promille-agtigt: 0..1000 = 0.0%..100.0%
fn aw_drawbar(tenths: u64) void = {
	const fill = (tenths * AW_BARW: u64 / 1000): size;
	fmt::print(AW_CYAN)!;
	aw_rep("█", fill);
	fmt::print(AW_IRON)!;
	aw_rep("░", AW_BARW - fill);
	fmt::print(AW_RESET, " ")!;
	if (tenths < 100) fmt::print("  ")! else if (tenths < 1000) fmt::print(" ")!;
	fmt::printf("{}.{}%", tenths / 10, tenths % 10)!;
};

fn aw_puthuman(n: u64) void = {
	const gib: u64 = 1024 * 1024 * 1024;
	if (n >= gib) {
		const t = n * 10 / gib;
		fmt::printf("{}.{} GB", t / 10, t % 10)!;
	} else {
		fmt::printf("{} MB", n / (1024 * 1024))!;
	};
};

fn aw_filesize(p: str) u64 = {
	match (os::stat(p)) {
	case let st: fs::filestat =>
		return st.sz: u64;
	case =>
		return 0;
	};
};

fn aw_isdir(p: str) bool = {
	match (os::stat(p)) {
	case let st: fs::filestat =>
		return fs::isdir(st.mode);
	case =>
		return false;
	};
};

fn aw_basename(p: str) str = {
	const b = strings::toutf8(p);
	let i = len(b);
	for (i > 0 && b[i - 1] != 47) { // /
		i -= 1;
	};
	return strings::fromutf8_unsafe(b[i..]);
};

fn aw_sortstrs(v: []str) void = {
	for (let i = 1z; i < len(v); i += 1) {
		let j = i;
		for (j > 0 && strings::compare(v[j - 1], v[j]) > 0) {
			const t = v[j];
			v[j] = v[j - 1];
			v[j - 1] = t;
			j -= 1;
		};
	};
};

fn aw_tail(path: str, n: size) void = {
	const f = match (os::open(path)) {
	case let f: io::file =>
		yield f;
	case =>
		return;
	};
	const data = match (io::drain(f)) {
	case let d: []u8 =>
		yield d;
	case =>
		aw_closeq(f);
		return;
	};
	aw_closeq(f);
	defer free(data);

	let lines: []str = [];
	defer free(lines);
	let start = 0z;
	for (let i = 0z; i <= len(data); i += 1) {
		if (i < len(data) && data[i] != 10) continue;
		if (i > start) append(lines, strings::fromutf8_unsafe(data[start..i]))!;
		start = i + 1;
	};
	const from = if (len(lines) > n) len(lines) - n else 0z;
	for (let i = from; i < len(lines); i += 1) {
		fmt::printfln("{}   {}{}", AW_IRON, lines[i], AW_RESET)!;
	};
};

fn aw_banner() void = {
	const inner = "   A N T E L O P E   W A R R I O R   ";
	const w = aw_runes(inner);
	fmt::print(AW_CYAN, AW_BOLD, "\n  ╔")!;
	aw_rep("═", w);
	fmt::println("╗")!;
	fmt::printfln("  ║{}║", inner)!;
	fmt::print("  ╚")!;
	aw_rep("═", w);
	fmt::println("╝", AW_RESET)!;
	fmt::printfln("{}        \\\\   //{}", AW_GOLD, AW_RESET)!;
	fmt::printfln("{}         \\\\_//    Dragon Warrior Tournament \u00b7 Palace Arena{}", AW_GOLD, AW_RESET)!;
	fmt::printfln("{}  motor    {}{}", AW_IRON, AW_RESET, aw_makemkvcon)!;
	fmt::printfln("{}  output   {}{}", AW_IRON, AW_RESET, aw_outdir)!;
};
