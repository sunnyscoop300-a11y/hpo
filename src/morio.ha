// morio -- FLAC to MP3 converter, integrated into hpo.
// Themed after the dawn-guarding rooster of Rooster Fighter: it stands
// watch over your lossless library and crows when a track converts.
// Wraps the standard `flac`, `lame`, and `metaflac` tools (same
// "wrap a trusted backend, add Hare on top" approach as the rest of hpo).
//
// All declarations are prefixed morio_ to avoid clashes with hpo's
// existing symbols in the same package.

use ascii;
use fmt;
use fs;
use io;
use os;
use os::exec;
use path;
use strings;
use strconv;
use unix;

type morio_options = struct {
	bitrate: uint,
	outdir: str,
	quiet: bool,
};

type morio_tags = struct {
	title: str,
	artist: str,
	album: str,
	track: str,
	year: str,
	genre: str,
};

type morio_error = (exec::error | fs::error | io::error | nomem | !exec::exit_status);

const morio_banner: str =
"     _\n"
"   =(')>  MORIO\n"
"    \")_)  -- the dawn rooster stands watch over your FLACs --\n";

const morio_crow_lines: [_]str = [
	"Kokekokkoo! Standing watch over your FLACs.",
	"The rooster spreads its feathers over the henhouse.",
	"Dawn breaks -- conversion begins.",
	"Not a single track slips past this crow.",
];

fn morio_empty_tags() morio_tags = morio_tags {
	title = "", artist = "", album = "", track = "", year = "", genre = "",
};

// Reads Vorbis comments via metaflac; missing tags stay empty.
fn morio_read_tags(inpath: str) (morio_tags | exec::error | io::error | nomem) = {
	let result = morio_empty_tags();

	const (rd, wr) = exec::pipe();
	let cmd = exec::cmd("metaflac",
		"--show-tag=TITLE",
		"--show-tag=ARTIST",
		"--show-tag=ALBUM",
		"--show-tag=TRACKNUMBER",
		"--show-tag=DATE",
		"--show-tag=GENRE",
		inpath)?;
	exec::addfile(&cmd, os::stdout_file, wr)?;

	const proc = exec::start(&cmd)?;
	io::close(wr)!;

	const data = io::drain(rd)?;
	defer free(data);
	io::close(rd)!;
	exec::wait(&proc)?;

	const text = strings::fromutf8(data)!;
	const lines = strings::split(text, "\n")!;
	defer free(lines);

	for (let i = 0z; i < len(lines); i += 1z) {
		const line = lines[i];
		if (len(line) == 0) {
			continue;
		};
		const (key, value) = strings::cut(line, "=");
		const upper = ascii::strupper(key)!;
		defer free(upper);
		switch (upper) {
		case "TITLE" => result.title = strings::dup(value)!;
		case "ARTIST" => result.artist = strings::dup(value)!;
		case "ALBUM" => result.album = strings::dup(value)!;
		case "TRACKNUMBER" => result.track = strings::dup(value)!;
		case "DATE" => result.year = strings::dup(value)!;
		case "GENRE" => result.genre = strings::dup(value)!;
		case => void;
		};
	};

	return result;
};

fn morio_tags_finish(t: *morio_tags) void = {
	free(t.title);
	free(t.artist);
	free(t.album);
	free(t.track);
	free(t.year);
	free(t.genre);
};

// Builds lame's --tt/--ta/... args for the non-empty tag fields.
fn morio_lame_tag_args(t: *morio_tags) []str = {
	let args: []str = [];
	if (len(t.title) > 0) {
		append(args, "--tt")!;
		append(args, t.title)!;
	};
	if (len(t.artist) > 0) {
		append(args, "--ta")!;
		append(args, t.artist)!;
	};
	if (len(t.album) > 0) {
		append(args, "--tl")!;
		append(args, t.album)!;
	};
	if (len(t.track) > 0) {
		append(args, "--tn")!;
		append(args, t.track)!;
	};
	if (len(t.year) > 0) {
		append(args, "--ty")!;
		append(args, t.year)!;
	};
	if (len(t.genre) > 0) {
		append(args, "--tg")!;
		append(args, t.genre)!;
	};
	return args;
};

fn morio_empty_tags_fallback() morio_tags = morio_tags {
	title = "", artist = "", album = "", track = "", year = "", genre = "",
};

// flac -> wav -> mp3, tags carried across. Returns the mp3 path written.
fn morio_convert_file(inpath: str, opts: *morio_options) (str | morio_error) = {
	const base = path::basename(inpath);

	// Strip a trailing ".flac"/".FLAC" as raw bytes (ASCII extension,
	// safe even if the stem has multi-byte runes like ae/oe/aa).
	const rawbase = strings::toutf8(base);
	const stembytes = if (len(rawbase) > 5) rawbase[..len(rawbase) - 5] else rawbase;
	const stem = strings::fromutf8(stembytes)!;

	const outdir = if (len(opts.outdir) > 0) {
		yield strings::dup(opts.outdir)!;
	} else {
		yield fmt::asprintf("{}/mp3", path::dirname(inpath))!;
	};
	defer free(outdir);
	os::mkdirs(outdir, 0o755: fs::mode)?;

	const outpath = fmt::asprintf("{}/{}.mp3", outdir, stem)!;

	const wavpath = fmt::asprintf("/tmp/morio-{}-{}.wav", unix::getpid(): int, stem)!;
	defer free(wavpath);
	defer _ = os::remove(wavpath);

	// 1. Decode FLAC -> temporary WAV.
	const decode = exec::cmd("flac", "-d", "-f", "-s", "-o", wavpath, inpath)?;
	const decproc = exec::start(&decode)?;
	const decstat = exec::wait(&decproc)?;
	exec::check(&decstat)?;

	// 2. Best-effort tag carry-over.
	let t = match (morio_read_tags(inpath)) {
	case let ok: morio_tags => yield ok;
	case => yield morio_empty_tags_fallback();
	};
	defer morio_tags_finish(&t);
	const tagargs = morio_lame_tag_args(&t);
	defer free(tagargs);

	// 3. Encode WAV -> MP3.
	const bitrate = fmt::asprintf("{}", opts.bitrate)!;
	defer free(bitrate);

	let encargs: []str = [];
	defer free(encargs);
	append(encargs, "-b")!;
	append(encargs, bitrate)!;
	append(encargs, "-h")!;
	append(encargs, tagargs...)!;
	append(encargs, wavpath)!;
	append(encargs, outpath)!;

	const encode = exec::cmd("lame", encargs...)?;
	const encproc = exec::start(&encode)?;
	const encstat = exec::wait(&encproc)?;
	exec::check(&encstat)?;

	return outpath;
};

fn morio_is_flac_name(name: str) bool = {
	return strings::hassuffix(name, ".flac") || strings::hassuffix(name, ".FLAC");
};

// Expands paths into a flat list of .flac files (dirs scanned one level).
fn morio_gather_flac_files(paths: []str) []str = {
	let result: []str = [];
	for (let p .. paths) {
		match (os::readdir(p)) {
		case let entries: []fs::dirent =>
			defer fs::dirents_free(entries);
			for (let e .. entries) {
				if (morio_is_flac_name(e.name)) {
					append(result, fmt::asprintf("{}/{}", p, e.name)!)!;
				};
			};
		case fs::error =>
			if (morio_is_flac_name(p)) {
				append(result, strings::dup(p)!)!;
			} else {
				fmt::errorfln("morio: skipping '{}' (not a .flac file or directory)", p)!;
			};
		case => abort();
		};
	};
	return result;
};

// hpo entry point: `hpo morio [-b kbps] [-o dir] [-q] <file-or-dir>...`
// Parses morio's own flags out of the argument list, then converts.
fn do_morio(o: *opts) void = {
	let bitrate = 320u;
	let outdir = "";
	let quiet = false;
	let inputs: []str = [];
	defer free(inputs);

	// Parse morio_args (everything after "hpo morio")
	const args = o.morio_args;
	let i = 0z;
	for (i < len(args); i += 1) {
		const a = args[i];
		if (a == "-b" && i + 1 < len(args)) {
			i += 1;
			match (strconv::stoi(args[i])) {
			case let n: int => bitrate = n: uint;
			case => cprint(C_RED, "MORIO", "ugyldig bitrate", o.nocolor);
			};
		} else if (a == "-o" && i + 1 < len(args)) {
			i += 1;
			outdir = args[i];
		} else if (a == "-q") {
			quiet = true;
		} else {
			append(inputs, a)!;
		};
	};

	if (len(inputs) == 0) {
		cprint(C_YELLOW, "MORIO", "Usage: hpo morio [-b kbps] [-o dir] [-q] <file-or-dir>...", o.nocolor);
		return;
	};

	let opt = morio_options {
		bitrate = bitrate,
		outdir = outdir,
		quiet = quiet,
	};

	if (!quiet && !o.nocolor) fmt::print(C_YELLOW)!;
	if (!quiet) fmt::println(morio_banner)!;
	if (!quiet && !o.nocolor) fmt::print(C_RESET)!;

	const files = morio_gather_flac_files(inputs);
	defer strings::freeall(files);

	if (len(files) == 0) {
		cprint(C_RED, "MORIO", "no .flac files found in the given paths", o.nocolor);
		return;
	};

	let converted = 0u;
	let failed = 0u;

	for (let j = 0z; j < len(files); j += 1z) {
		const f = files[j];
		if (!quiet) {
			fmt::printf("\r[{}/{}] converting {}...", j, len(files), f)!;
		};
		match (morio_convert_file(f, &opt)) {
		case let outpath: str =>
			free(outpath);
			converted += 1;
			if (!quiet) {
				fmt::errorfln(">> {}", morio_crow_lines[j % len(morio_crow_lines)])!;
			};
		case let err: morio_error =>
			failed += 1;
			match (err) {
			case let e: exec::error =>
				fmt::errorfln("morio: failed to convert {}: {}", f, exec::strerror(e))!;
			case let e: fs::error =>
				fmt::errorfln("morio: failed to convert {}: {}", f, fs::strerror(e))!;
			case let e: io::error =>
				fmt::errorfln("morio: failed to convert {}: {}", f, io::strerror(e))!;
			case nomem =>
				fmt::errorfln("morio: failed to convert {}: out of memory", f)!;
			case let e: exec::exit_status =>
				fmt::errorfln("morio: failed to convert {}: {}", f, exec::exitstr(e))!;
			};
		};
	};

	if (!quiet) fmt::println("")!;

	if (failed == 0) {
		if (!o.nocolor) fmt::print(C_GREEN)!;
		fmt::printfln("   Kokekokkoo! {} converted. The henhouse is safe.", converted)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
	} else {
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		fmt::printfln("   The rooster took a few hits: {} converted, {} failed.", converted, failed)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
	};
};
