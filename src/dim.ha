// Dim — panda-landsbyens CD-brænder
// Sums tvillingebror og Po's fætter. Han ruller, Sum spiser dumplings,
// og sammen får de dine sange ned på en skive.
//
// hpo-kommando — læg filen ved siden af fenghuang.ha og kald
// do_dim(args) fra dispatch i main.ha.
// brug:  hpo dim [mappe] [drev] [fart]   (standard: .  /dev/sr0  8)
//
// kræver: ffprobe, ffmpeg, wodim, sudo

use bufio;
use fmt;
use fs;
use io;
use math::random;
use os;
use os::exec;
use strconv;
use strings;
use time;

type dim_spor = struct {
	fil: str,
	navn: str,
	sek: f64,
};

def DIM_MAX_SEK: f64 = 4740.0; // 79 min
def DIM_TMP: str = "/tmp/dim-brand";

def DIM_NUL: str = "\x1b[0m";
def DIM_BAMBUS: str = "\x1b[38;5;70m";
def DIM_SNE: str = "\x1b[38;5;255m";
def DIM_GRAA: str = "\x1b[38;5;244m";
def DIM_ROED: str = "\x1b[38;5;196m";
def DIM_GROEN: str = "\x1b[38;5;46m";
def DIM_ORANGE: str = "\x1b[38;5;208m";

let dim_rng: random::random = 0;

const DIM_AFBRUDT: []str = [
	"tilbage til bambussen",
	"Dim faldt i søvn på bambussen",
	"Sum spiste dumplingen før brændingen",
	"Dim ruller hjem til mor panda",
	"Po kom forbi med nudler, så det må vente",
	"tvillingerne skal lige lege rullepanda først",
];

const DIM_TOM: []str = [
	"Ingen lydfiler — Dim ruller tomhændet hjem.",
	"Ingen lydfiler — Sum har vist spist dem alle.",
	"Ingen lydfiler — kun bambusblade her.",
];

const DIM_RULLER: []str = [
	"Dim ruller — tag ikke disken ud...",
	"Dim ruller ned ad bakken med din CD — tag ikke disken ud...",
	"Sum holder skiven, Dim trykker på knappen — tag ikke disken ud...",
	"Dim har sit mest seriøse pandaansigt på — tag ikke disken ud...",
];

const DIM_BRAENDT: []str = [
	"BRÆNDT — disken er skubbet ud. Dumplings til alle!",
	"BRÆNDT — Dim og Sum giver hinanden tvilling-high-five!",
	"BRÆNDT — Po ville være stolt af sine fætre!",
	"BRÆNDT — tid til en lur i bambusskoven.",
	"BRÆNDT — hele panda-landsbyen danser!",
];

const DIM_FEJL: []str = [
	"Dim rullede ind i et træ",
	"Sum satte sig på brænderen",
	"Dim snublede over en dumpling",
	"Dim blev distraheret af en sommerfugl",
];

const DIM_TAO: []str = [
	"DAO fejlede — Dim prøver igen med TAO...",
	"DAO fejlede — Dim børster bambus af sig og prøver med TAO...",
	"DAO fejlede — Sum siger: prøv TAO! Dim prøver TAO...",
];

fn dim_vaelg(l: []str) str = l[random::u64n(&dim_rng, len(l): u64): size];

// args = alt efter "dim", fx ["~/Music/album", "/dev/sr0", "8"]
fn do_dim(args: []str) void = {
	const mappe = if (len(args) > 0) args[0] else ".";
	const drev = if (len(args) > 1) args[1] else "/dev/sr0";
	const fart = if (len(args) > 2) args[2] else "8";
	const nu = time::now(time::clock::REALTIME);
	dim_rng = random::init((nu.sec: u64) ^ (nu.nsec: u64));

	dim_banner(mappe, drev);
	fmt::printfln("  hastighed: x{}  {}(drevet runder op hvis det ikke kan præcis den){}\n",
		fart, DIM_GRAA, DIM_NUL)!;

	match (os::stat(mappe)) {
	case let st: fs::filestat =>
		if (!fs::isdir(st.mode)) {
			fmt::printfln("  {}Det er ikke en mappe: {}{}\n", DIM_ROED, mappe, DIM_NUL)!;
			return;
		};
	case let e: fs::error =>
		fmt::printfln("  {}Dim kan ikke åbne mappen: {} ({}){}\n",
			DIM_ROED, mappe, fs::strerror(e), DIM_NUL)!;
		return;
	};

	// find lydfiler
	let liste: []dim_spor = [];
	const it = match (os::iter(mappe)) {
	case let i: *fs::iterator =>
		yield i;
	case fs::error =>
		fmt::printfln("  {}Kunne ikke læse mappen.{}\n", DIM_ROED, DIM_NUL)!;
		return;
	};
	for (true) {
		const d = match (fs::next(it)) {
		case let d: fs::dirent =>
			yield d;
		case =>
			break;
		};
		if (!dim_er_lyd(d.name)) continue;
		append(liste, dim_spor {
			fil = strings::concat(mappe, "/", d.name)!,
			navn = strings::dup(d.name)!,
			sek = 0.0,
		})!;
	};
	fs::finish(it);

	if (len(liste) == 0) {
		fmt::printfln("  {}{}{}\n", DIM_ROED, dim_vaelg(DIM_TOM), DIM_NUL)!;
		return;
	};
	dim_sorter(liste);

	// varigheder
	fmt::printfln("  {}Sum tæller dumplings... (læser varigheder){}", DIM_GRAA, DIM_NUL)!;
	bufio::flush(os::stdout)!;
	for (let i = 0z; i < len(liste); i += 1) {
		liste[i].sek = dim_varighed(liste[i].fil);
	};
	fmt::print("\r\x1b[K")!;

	// sporliste
	let total = 0.0;
	for (let i = 0z; i < len(liste); i += 1) {
		const s = liste[i];
		total += s.sek;
		const farve = if (total > DIM_MAX_SEK) DIM_ROED else DIM_NUL;
		const navn = dim_kort(s.navn, 48);
		const t = dim_tid(s.sek);
		fmt::printf("  {}{}{}. {}", farve,
			if (i + 1 < 10) " " else "", i + 1, navn)!;
		dim_mellemrum(48 - dim_runer(navn) + 1);
		dim_mellemrum(6 - dim_runer(t));
		fmt::printfln("{}{}", t, DIM_NUL)!;
	};

	const status = if (total > DIM_MAX_SEK)
		strings::concat(DIM_ROED, "⚠ OVER 79 MIN — selv Dim kan ikke presse den ind", DIM_NUL)!
	else
		strings::concat(DIM_GROEN, "✓ passer på CD", DIM_NUL)!;
	fmt::printfln("\n  total: {}   {}", dim_tid(total), status)!;
	// tiendedele i hånden: {:.1} er upålidelig på tværs af Hare-versioner
	let tiende = ((DIM_MAX_SEK - total) * 10.0 / 60.0): i64;
	const minus = if (tiende < 0) "-" else "";
	if (tiende < 0) tiende = -tiende;
	fmt::printfln("  plads tilbage: {}{}.{} min\n", minus, tiende / 10, tiende % 10)!;

	// bekræft
	fmt::print("  Skal Dim rulle i gang? [j/N] ")!;
	bufio::flush(os::stdout)!;
	let svar = "";
	match (bufio::read_line(os::stdin)) {
	case let b: []u8 =>
		svar = strings::fromutf8(b)!;
	case =>
		void;
	};
	svar = strings::trim(svar);
	if (svar != "j" && svar != "J") {
		fmt::printfln("  [afbrudt — {}]\n", dim_vaelg(DIM_AFBRUDT))!;
		return;
	};

	// konverter
	match (os::mkdirs(DIM_TMP, 0o755)) {
	case void => void;
	case fs::error =>
		fmt::printfln("  {}Kunne ikke lave {}{}\n", DIM_ROED, DIM_TMP, DIM_NUL)!;
		return;
	};
	fmt::printfln("\n  {}Sum og Dim koger til CD-audio (44.1kHz 16bit stereo)...{}",
		DIM_ORANGE, DIM_NUL)!;

	let wavs: []str = [];
	for (let i = 0z; i < len(liste); i += 1) {
		const nr = i + 1;
		const ud = fmt::asprintf("{}/{}{}.wav", DIM_TMP,
			if (nr < 10) "0" else "", nr)!;
		fmt::printf("\r  [{}/{}] {}\x1b[K", nr, len(liste),
			dim_kort(liste[i].navn, 40))!;
		bufio::flush(os::stdout)!;
		// ren 44-byte WAV-header: ingen tags, ingen cover, bitexact
		dim_koer("ffmpeg", "-y", "-loglevel", "error", "-i", liste[i].fil,
			"-vn", "-map_metadata", "-1", "-fflags", "+bitexact",
			"-flags:a", "+bitexact",
			"-ar", "44100", "-ac", "2", "-sample_fmt", "s16",
			"-c:a", "pcm_s16le", ud);
		append(wavs, ud)!;
	};
	fmt::print("\r\x1b[K")!;
	fmt::printfln("  {}✓ konvertering færdig{}\n", DIM_GROEN, DIM_NUL)!;
	fmt::printfln("  {}{}{}\n", DIM_ORANGE, dim_vaelg(DIM_RULLER), DIM_NUL)!;

	// brænd
	let cmd: []str = [];
	append(cmd, ["sudo", "wodim", strings::concat("dev=", drev)!, "-v",
		"-dao", "-audio", "-pad", strings::concat("speed=", fart)!, "-eject"]...)!;
	append(cmd, wavs...)!;

	let kode = dim_koer(cmd...);
	if (kode != 0) {
		fmt::printfln("\n  {}{}{}\n", DIM_ORANGE, dim_vaelg(DIM_TAO), DIM_NUL)!;
		cmd[4] = "-tao";
		kode = dim_koer(cmd...);
	};
	if (kode == 0) {
		fmt::printfln("\n  {}✓ {}{}\n", DIM_GROEN, dim_vaelg(DIM_BRAENDT), DIM_NUL)!;
	} else {
		fmt::printfln("\n  {}✗ fejl (exit {}) — {}{}\n",
			DIM_ROED, kode, dim_vaelg(DIM_FEJL), DIM_NUL)!;
	};

	// ryd op
	for (let w .. wavs) {
		match (os::remove(w)) {
		case => void;
		};
	};
};

fn dim_banner(mappe: str, drev: str) void = {
	fmt::println()!;
	fmt::printfln("  {}╔════════════════════════════════════╗{}", DIM_BAMBUS, DIM_NUL)!;
	fmt::printfln("  {}║{}              D  I  M               {}║{}",
		DIM_BAMBUS, DIM_SNE, DIM_BAMBUS, DIM_NUL)!;
	fmt::printfln("  {}║{}    panda-landsbyens CD-brænder     {}║{}",
		DIM_BAMBUS, DIM_GRAA, DIM_BAMBUS, DIM_NUL)!;
	fmt::printfln("  {}╚════════════════════════════════════╝{}", DIM_BAMBUS, DIM_NUL)!;
	fmt::printfln("  mappe: {}   drev: {}\n", mappe, drev)!;
};

// ffprobe → sekunder (0 ved fejl)
fn dim_varighed(fil: str) f64 = {
	let cmd = match (exec::cmd("ffprobe", "-v", "error", "-show_entries",
		"format=duration", "-of", "default=noprint_wrappers=1:nokey=1", fil)) {
	case let c: exec::command =>
		yield c;
	case =>
		return 0.0;
	};
	const (rd, wr) = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, wr)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		io::close(rd)!;
		io::close(wr)!;
		return 0.0;
	};
	io::close(wr)!;

	let data: []u8 = [];
	match (io::drain(rd)) {
	case let b: []u8 =>
		data = b;
	case =>
		void;
	};
	io::close(rd)!;
	match (exec::wait(&proc)) {
	case => void;
	};

	const s = match (strings::fromutf8(data)) {
	case let s: str =>
		yield strings::trim(s);
	case =>
		return 0.0;
	};
	match (strconv::stof64(s)) {
	case let v: f64 =>
		return v;
	case =>
		return 0.0;
	};
};

// kør en kommando med arvet stdio, returnér exit-kode
fn dim_koer(args: str...) int = {
	bufio::flush(os::stdout)!;
	let cmd = match (exec::cmd(args[0], args[1..]...)) {
	case let c: exec::command =>
		yield c;
	case let e: exec::error =>
		fmt::errorfln("  kunne ikke starte {}: {}", args[0], exec::strerror(e))!;
		return 127;
	};
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		return 127;
	};
	const st = match (exec::wait(&proc)) {
	case let s: exec::status =>
		yield s;
	case =>
		return 127;
	};
	match (exec::exit(&st)) {
	case let c: exec::exited =>
		return c: int;
	case exec::signaled =>
		return 128;
	};
};

fn dim_er_lyd(navn: str) bool = {
	const exts = [".mp3", ".flac", ".wav", ".m4a", ".ogg"];
	for (let e .. exts) {
		if (dim_slutter_ci(navn, e)) return true;
	};
	return false;
};

fn dim_slutter_ci(s: str, ext: str) bool = {
	const b = strings::toutf8(s);
	const x = strings::toutf8(ext);
	if (len(b) < len(x)) return false;
	const off = len(b) - len(x);
	for (let i = 0z; i < len(x); i += 1) {
		let c = b[off + i];
		if (c >= 'A' && c <= 'Z') c += 32;
		if (c != x[i]) return false;
	};
	return true;
};

fn dim_sorter(l: []dim_spor) void = {
	for (let i = 1z; i < len(l); i += 1) {
		const v = l[i];
		let j = i;
		for (j > 0 && strings::compare(l[j - 1].navn, v.navn) > 0; j -= 1) {
			l[j] = l[j - 1];
		};
		l[j] = v;
	};
};

fn dim_tid(sek: f64) str = {
	const t = sek: int;
	const m = t / 60, s = t % 60;
	return fmt::asprintf("{}:{}{}", m, if (s < 10) "0" else "", s)!;
};

fn dim_runer(s: str) int = {
	let n = 0;
	let it = strings::iter(s);
	for (true) {
		match (strings::next(&it)) {
		case rune =>
			n += 1;
		case =>
			break;
		};
	};
	return n;
};

// strings::sub bruger rune-indekser, så æøå/japansk klippes rent
fn dim_kort(s: str, n: int) str = {
	if (dim_runer(s) <= n) return s;
	return strings::concat(strings::sub(s, 0, (n - 1): size), "…")!;
};

fn dim_mellemrum(n: int) void = {
	for (let i = 0; i < n; i += 1) fmt::print(" ")!;
};
