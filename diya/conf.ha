// Indstillinger og bogmærker i ~/.config/diya/diya.conf
// Format: én "nøgle<TAB>værdi" pr. linje
//   tema     kantine | nat | dag
//   str      skriftstørrelse i px
//   sidst    sidst læste bog
//   p:<bog>  side/sider
use fmt;
use fs;
use io;
use os;
use strconv;
use strings;

fn conf_path() str = strings::concat(cfgdir, "/diya.conf")!;

// Returnerer en kopi af værdien (kalderen frigør) eller void.
fn kv_get(key: str) (str | void) = {
	const p = conf_path();
	defer free(p);
	const data = match (readfile(p)) {
	case let s: str =>
		yield s;
	case void =>
		return;
	};
	defer free(data);

	let tok = strings::tokenize(data, "\n");
	for (true) {
		const line = match (strings::next_token(&tok)) {
		case let l: str =>
			yield l;
		case =>
			break;
		};
		const (k, v) = strings::cut(line, "\t");
		if (k == key) return strings::dup(v)!;
	};
	return;
};

fn kv_set(key: str, val: str) void = {
	const p = conf_path();
	defer free(p);

	let old = "";
	let owned = false;
	match (readfile(p)) {
	case let s: str =>
		old = s;
		owned = true;
	case void => void;
	};
	defer if (owned) free(old);

	const f = match (os::create(p, 0o644: fs::mode)) {
	case let f: io::file =>
		yield f;
	case =>
		return;
	};
	defer closef(f);

	let tok = strings::tokenize(old, "\n");
	for (true) {
		const line = match (strings::next_token(&tok)) {
		case let l: str =>
			yield l;
		case =>
			break;
		};
		if (len(line) == 0) continue;
		const (k, _) = strings::cut(line, "\t");
		if (k == key) continue;
		put(f, line);
		put(f, "\n");
	};
	put(f, key);
	put(f, "\t");
	put(f, val);
	put(f, "\n");
};

fn theme() str = {
	match (kv_get("tema")) {
	case let t: str =>
		if (t == "dag" || t == "nat" || t == "kantine") return t;
		free(t);
	case void => void;
	};
	return strings::dup("kantine")!;
};

// true = rul med musen, false = side for side
fn scrollmode() bool = {
	match (kv_get("visning")) {
	case let v: str =>
		const r = v == "rul";
		free(v);
		return r;
	case void =>
		return false;
	};
};

fn fontsize() size = {
	const v = match (kv_get("str")) {
	case let v: str =>
		yield v;
	case void =>
		return 20;
	};
	defer free(v);
	match (strconv::stoz(v)) {
	case let n: size =>
		if (n >= 14 && n <= 30) return n;
	case => void;
	};
	return 20;
};

// (side, sider) — 1-baseret side, (0, 0) hvis bogen aldrig er åbnet
fn progress(name: str) (size, size) = {
	const k = strings::concat("p:", name)!;
	defer free(k);
	const v = match (kv_get(k)) {
	case let v: str =>
		yield v;
	case void =>
		return (0z, 0z);
	};
	defer free(v);
	const (a, b) = strings::cut(v, "/");
	const page = match (strconv::stoz(a)) {
	case let n: size =>
		yield n;
	case =>
		yield 0z;
	};
	const total = match (strconv::stoz(b)) {
	case let n: size =>
		yield n;
	case =>
		yield 0z;
	};
	return (page, total);
};

fn save_progress(name: str, page: size, total: size) void = {
	const k = strings::concat("p:", name)!;
	defer free(k);
	const v = fmt::asprintf("{}/{}", page, total)!;
	defer free(v);
	kv_set(k, v);
	kv_set("sidst", name);
};
