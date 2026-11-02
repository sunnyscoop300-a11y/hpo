// CBZ/CBR: tegneserier = arkiver fulde af billeder.
// Pakkes ud én gang til ~/.cache/diya/<bog>/ (fladt, uden undermapper),
// og hvert billede bliver én side i bogen.
//   .cbz -> unzip -j
//   .cbr -> unrar e, ellers 7z e (bruges også hvis en .cbz i virkeligheden er RAR)
use fs;
use io;
use os;
use os::exec;
use strings;

fn is_comic(name: str) bool =
	strings::hassuffix(name, ".cbz") || strings::hassuffix(name, ".CBZ")
	|| strings::hassuffix(name, ".cbr") || strings::hassuffix(name, ".CBR");

fn is_image(n: str) bool = {
	const exts: [_]str = [".jpg", ".JPG", ".jpeg", ".JPEG", ".png", ".PNG",
		".gif", ".GIF", ".webp", ".WEBP"];
	for (let i = 0z; i < len(exts); i += 1) {
		if (strings::hassuffix(n, exts[i])) return true;
	};
	return false;
};

// Starter et program og venter på at det er færdigt.
fn run_wait(cmd: *exec::command) void = {
	let proc = match (exec::start(cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		return;
	};
	match (exec::wait(&proc)) {
	case exec::status => void;
	case => void;
	};
};

fn has_images(dir: str) bool = {
	const ents = match (os::readdir(dir)) {
	case let e: []fs::dirent =>
		yield e;
	case =>
		return false;
	};
	defer fs::dirents_free(ents);
	for (let i = 0z; i < len(ents); i += 1) {
		if (is_image(ents[i].name)) return true;
	};
	return false;
};

// Pakker tegneserien ud (kun første gang). Returnerer cache-mappen.
fn comic_dir(name: str) (str | void) = {
	const dir = strings::concat(cachedir, "/", name)!;
	const marker = strings::concat(dir, "/.diya-ok")!;
	defer free(marker);
	if (os::exists(marker)) return dir;

	const src = strings::concat(bookdir, "/", name)!;
	defer free(src);
	match (os::mkdirs(dir, 0o755: fs::mode)) {
	case void => void;
	case fs::error =>
		free(dir);
		return;
	};

	const cbr = strings::hassuffix(name, ".cbr") || strings::hassuffix(name, ".CBR");
	if (!cbr) {
		// -j smider mapperne væk, så alle billeder ligger fladt
		match (exec::cmd("unzip", "-o", "-qq", "-j", src, "-d", dir)) {
		case let c: exec::command =>
			run_wait(&c);
		case => void;
		};
	};
	if (!has_images(dir)) {
		const dslash = strings::concat(dir, "/")!;
		defer free(dslash);
		match (exec::cmd("unrar", "e", "-o+", "-inul", src, dslash)) {
		case let c: exec::command =>
			run_wait(&c);
		case => void;
		};
	};
	if (!has_images(dir)) {
		const odir = strings::concat("-o", dir)!;
		defer free(odir);
		match (exec::cmd("7z", "e", "-y", "-bso0", "-bsp0", odir, src)) {
		case let c: exec::command =>
			run_wait(&c);
		case => void;
		};
	};
	if (!has_images(dir)) {
		free(dir);
		return;
	};
	match (os::create(marker, 0o644: fs::mode)) {
	case let f: io::file =>
		closef(f);
	case => void;
	};
	return dir;
};

// Naturlig rækkefølge: "side2.jpg" kommer før "side10.jpg"
fn natcmp(a: str, b: str) int = {
	const x = strings::toutf8(a);
	const y = strings::toutf8(b);
	let i = 0z;
	let j = 0z;
	for (i < len(x) && j < len(y)) {
		const dx = x[i] >= 0x30 && x[i] <= 0x39;
		const dy = y[j] >= 0x30 && y[j] <= 0x39;
		if (dx && dy) {
			// foranstillede nuller tæller ikke
			for (i < len(x) && x[i] == 0x30) i += 1;
			for (j < len(y) && y[j] == 0x30) j += 1;
			let ei = i;
			for (ei < len(x) && x[ei] >= 0x30 && x[ei] <= 0x39) ei += 1;
			let ej = j;
			for (ej < len(y) && y[ej] >= 0x30 && y[ej] <= 0x39) ej += 1;
			// flere cifre = større tal
			if (ei - i != ej - j) return if (ei - i < ej - j) -1 else 1;
			for (i < ei) {
				if (x[i] != y[j]) return if (x[i] < y[j]) -1 else 1;
				i += 1;
				j += 1;
			};
			continue;
		};
		if (x[i] != y[j]) return if (x[i] < y[j]) -1 else 1;
		i += 1;
		j += 1;
	};
	if (len(x) - i == len(y) - j) return 0;
	return if (len(x) - i < len(y) - j) -1 else 1;
};

fn load_comic(name: str) (book | void) = {
	const dir = match (comic_dir(name)) {
	case let d: str =>
		yield d;
	case void =>
		return;
	};
	defer free(dir);
	const ents = match (os::readdir(dir)) {
	case let e: []fs::dirent =>
		yield e;
	case =>
		return;
	};
	defer fs::dirents_free(ents);

	let pics: []str = [];
	defer free(pics);
	for (let i = 0z; i < len(ents); i += 1) {
		const n = ents[i].name;
		if (strings::hasprefix(n, ".") || !is_image(n)) continue;
		append(pics, n)!;
	};

	// indsætningssortering i naturlig rækkefølge
	for (let i = 1z; i < len(pics); i += 1) {
		let j = i;
		for (j > 0 && natcmp(pics[j - 1], pics[j]) > 0) {
			const t = pics[j];
			pics[j] = pics[j - 1];
			pics[j - 1] = t;
			j -= 1;
		};
	};

	let b = book { chunks = [], kinds = [], pages = [] };
	for (let i = 0z; i < len(pics); i += 1) {
		add_chunk(&b, strings::dup(pics[i])!, kind::IMG);
	};
	if (len(b.chunks) == 0) {
		add_chunk(&b, strings::dup("(Diya kunne ikke finde billeder i denne tegneserie)")!, kind::TEXT);
	};
	paginate(&b);
	return b;
};
