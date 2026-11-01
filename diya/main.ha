// DIYA — e-bogslæser i Hare
// Hare kører serveren, læser bøgerne, paginerer, gemmer bogmærker
// og genererer al HTML. Browseren er bare skærmen.
//
// Byg:  hare build -o diya .
// Kør:  ./diya            (bøger fra ~/Diya, åbner browseren)
//       ./diya ~/Bøger    (anden mappe)
//       ./diya -n -p 7071 (ingen browser, anden port)
use fmt;
use fs;
use io;
use net;
use net::ip;
use net::tcp;
use os;
use os::exec;
use strconv;
use strings;
use time;

def PORT: u16 = 7070;

let bookdir: str = "";
let cfgdir: str = "";
// Nøgle til "Luk Diya" — ny for hver opstart, så en gammel fane ikke kan lukke hende
let token: str = "";

fn home() str = match (os::getenv("HOME")) {
case let h: str =>
	yield h;
case void =>
	yield "/tmp";
};

export fn main() void = {
	let nobrowser = false;
	let port = PORT;
	let dir = "";

	for (let i = 1z; i < len(os::args); i += 1) {
		const a = os::args[i];
		if (a == "-n") {
			nobrowser = true;
		} else if (a == "-p" && i + 1 < len(os::args)) {
			i += 1;
			port = match (strconv::stou16(os::args[i])) {
			case let p: u16 =>
				yield p;
			case =>
				yield PORT;
			};
		} else if (a == "-h" || a == "--help") {
			fmt::println("diya [-n] [-p port] [bogmappe]")!;
			fmt::println("  -n   åbn ikke browseren")!;
			fmt::println("  -p   port (standard 7070)")!;
			return;
		} else {
			dir = a;
		};
	};

	const h = home();
	bookdir = if (len(dir) > 0) strings::dup(dir)!
		else strings::concat(h, "/Diya")!;
	cfgdir = strings::concat(h, "/.config/diya")!;
	cachedir = strings::concat(h, "/.cache/diya")!;
	const now = time::now(time::clock::REALTIME);
	token = fmt::asprintf("{}{}", now.sec, now.nsec)!;

	match (os::mkdirs(bookdir, 0o755: fs::mode)) {
	case void => void;
	case fs::error => void;
	};
	match (os::mkdirs(cfgdir, 0o755: fs::mode)) {
	case void => void;
	case fs::error => void;
	};
	match (os::mkdirs(cachedir, 0o755: fs::mode)) {
	case void => void;
	case fs::error => void;
	};

	const sock = match (tcp::listen(ip::LOCAL_V4, port, void: tcp::reuseaddr)) {
	case let s: net::socket =>
		yield s;
	case =>
		fmt::fatalf("Diya kan ikke åbne port {} — kører hun allerede? "
			"Prøv igen om lidt eller brug -p", port);
	};

	const url = fmt::asprintf("http://127.0.0.1:{}/", port)!;
	defer free(url);
	fmt::println("")!;
	fmt::println("  \x1b[38;5;178m◉\x1b[0m \x1b[1mD I Y A\x1b[0m  — læsehjørnet er åbent")!;
	fmt::printfln("  \x1b[38;5;180mbøger:\x1b[0m {}", bookdir)!;
	fmt::printfln("  \x1b[38;5;180mlæs her:\x1b[0m \x1b[4m{}\x1b[0m", url)!;
	fmt::println("  \x1b[2m(Ctrl+C eller \"Luk Diya\" i browseren for at stoppe)\x1b[0m")!;
	fmt::println("")!;

	if (!nobrowser) open_browser(url);

	for (true) {
		const conn = match (net::accept(sock)) {
		case let s: net::socket =>
			yield s;
		case =>
			continue;
		};
		const go = handle(conn);
		closef(conn);
		if (!go) break;
	};
	closef(sock);
	fmt::println("  Diya lukker kantinen. Vi ses.")!;
};

fn open_browser(url: str) void = {
	let cmd = match (exec::cmd("xdg-open", url)) {
	case let c: exec::command =>
		yield c;
	case =>
		return;
	};
	match (exec::start(&cmd)) {
	case exec::process => void;
	case => void;
	};
};

// Én forespørgsel. Returnerer false når serveren skal stoppe.
fn handle(c: io::file) bool = {
	let buf: [8192]u8 = [0...];
	const n = match (io::read(c, buf[..])) {
	case let n: size =>
		yield n;
	case =>
		return true;
	};
	const req = match (strings::fromutf8(buf[..n])) {
	case let s: str =>
		yield s;
	case =>
		return true;
	};

	const (line, _) = strings::cut(req, "\r\n");
	const (method, rest) = strings::cut(line, " ");
	const (target, _) = strings::cut(rest, " ");
	const (path, query) = strings::cut(target, "?");

	if (path != "/img" && path != "/favicon.ico" && path != "/mark"
			&& !strings::hasprefix(path, "/epub/")) {
		logreq(method, target);
	};

	// Lukning kun via POST med dagens nøgle — browsere forudindlæser
	// gerne links (GET) og gendanner gamle faner
	if (method == "POST" && path == "/luk") {
		match (qget(query, "k")) {
		case let k: str =>
			if (k == token) {
				page_bye(c);
				return false;
			};
		case void => void;
		};
		redirect(c, "/");
		return true;
	};

	if (method != "GET") {
		send_head(c, "405 Method Not Allowed", "text/plain; charset=utf-8");
		put(c, "Diya tager kun imod GET.\n");
		return true;
	};

	if (path == "/") {
		page_library(c);
	} else if (path == "/laes") {
		page_reader(c, query);
	} else if (path == "/mark") {
		route_mark(c, query);
	} else if (path == "/img") {
		page_img(c, query);
	} else if (strings::hasprefix(path, "/epub/")) {
		page_epubfile(c, path);
	} else if (path == "/tema" || path == "/str" || path == "/visning") {
		route_setting(c, path, query);
	} else if (path == "/luk") {
		page_luk(c);
	} else if (path == "/favicon.ico") {
		put(c, "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n");
	} else {
		page_notfound(c);
	};
	return true;
};

// Henter en værdi fra ?a=1&b=2
fn qget(q: str, key: str) (str | void) = {
	let tok = strings::tokenize(q, "&");
	for (true) {
		const pair = match (strings::next_token(&tok)) {
		case let t: str =>
			yield t;
		case =>
			break;
		};
		const (k, v) = strings::cut(pair, "=");
		if (k == key) return v;
	};
	return;
};

fn qnum(q: str, key: str) (size | void) = {
	const s = match (qget(q, key)) {
	case let s: str =>
		yield s;
	case void =>
		return;
	};
	match (strconv::stoz(s)) {
	case let n: size =>
		return n;
	case =>
		return;
	};
};

fn route_setting(c: io::handle, path: str, q: str) void = {
	if (path == "/tema") {
		match (qget(q, "t")) {
		case let t: str =>
			if (t == "dag" || t == "nat" || t == "kantine") {
				kv_set("tema", t);
			};
		case void => void;
		};
	} else if (path == "/visning") {
		match (qget(q, "v")) {
		case let v: str =>
			if (v == "rul" || v == "sider") kv_set("visning", v);
		case void => void;
		};
	} else {
		let px = fontsize();
		match (qget(q, "d")) {
		case let d: str =>
			if (d == "op" && px < 30) px += 2;
			if (d == "ned" && px > 14) px -= 2;
		case void => void;
		};
		const v = fmt::asprintf("{}", px)!;
		kv_set("str", v);
		free(v);
	};

	// tilbage til siden man kom fra
	match (qnum(q, "bog")) {
	case let b: size =>
		const loc = match (qnum(q, "side")) {
		case let s: size =>
			yield fmt::asprintf("/laes?bog={}&side={}", b, s)!;
		case void =>
			// brug bogmærket — i rulle-mode med #sN så browseren hopper derned
			const books = list_books();
			defer strings::freeall(books);
			let pg = 0z;
			if (b < len(books)) {
				const (x, _) = progress(books[b]);
				pg = x;
			};
			yield if (scrollmode() && pg > 1)
				fmt::asprintf("/laes?bog={}#s{}", b, pg)!
				else fmt::asprintf("/laes?bog={}", b)!;
		};
		redirect(c, loc);
		free(loc);
	case void =>
		redirect(c, "/");
	};
};

// 1×1 gennemsigtig GIF — svaret på /mark
const PIXEL: [_]u8 = [
	0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
	0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x21, 0xF9, 0x04, 0x01, 0x00,
	0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
	0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3B,
];

// GET /mark?bog=N&side=S&af=T — en lazy pixel i rulle-mode.
// Browseren henter den lidt før siden er på skærmen, derfor side-1,
// og bogmærket rykker kun frem (ellers ville siderne øverst snyde).
fn route_mark(c: io::handle, q: str) void = {
	const books = list_books();
	defer strings::freeall(books);
	match (qnum(q, "bog")) {
	case let bi: size =>
		match (qnum(q, "side")) {
		case let s: size =>
			match (qnum(q, "af")) {
			case let t: size =>
				if (bi < len(books) && s >= 1 && s <= t) {
					const (cur, _) = progress(books[bi]);
					const s2 = if (s > 1) s - 1 else 1z;
					if (s2 > cur) save_progress(books[bi], s2, t);
				};
			case void => void;
			};
		case void => void;
		};
	case void => void;
	};
	putf(c, "HTTP/1.1 200 OK\r\nContent-Type: image/gif\r\nContent-Length: {}\r\n"
		"Cache-Control: no-store\r\nConnection: close\r\n\r\n", len(PIXEL));
	putb(c, PIXEL[..]);
};

// --- små I/O-hjælpere: en browser der lukker fanen må ikke dræbe Diya ---

fn put(h: io::handle, s: str) void = putb(h, strings::toutf8(s));

fn putb(h: io::handle, b: []u8) void = {
	match (io::writeall(h, b)) {
	case size => void;
	case io::error => void;
	};
};

fn putf(h: io::handle, f: str, args: fmt::field...) void = {
	match (fmt::fprintf(h, f, args...)) {
	case size => void;
	case io::error => void;
	};
};

fn logreq(method: str, target: str) void = {
	match (fmt::printfln("  \x1b[2m{} {}\x1b[0m", method, target)) {
	case size => void;
	case io::error => void;
	};
};

fn closef(f: io::file) void = {
	match (io::close(f)) {
	case void => void;
	case io::error => void;
	};
};

fn send_head(c: io::handle, status: str, ctype: str) void = {
	putf(c, "HTTP/1.1 {}\r\nContent-Type: {}\r\n"
		"Cache-Control: no-store\r\nConnection: close\r\n\r\n",
		status, ctype);
};

fn redirect(c: io::handle, loc: str) void = {
	putf(c, "HTTP/1.1 303 See Other\r\nLocation: {}\r\n"
		"Content-Length: 0\r\nConnection: close\r\n\r\n", loc);
};
