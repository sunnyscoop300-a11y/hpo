// EPUB: pakkes ud én gang til ~/.cache/diya/<bog>/ med unzip,
// derefter læser Hare container.xml -> OPF (titel + spine) -> XHTML-kapitler
// og laver dem om til afsnit og overskrifter.
use bytes;
use fmt;
use fs;
use io;
use os;
use os::exec;
use strconv;
use strings;

let cachedir: str = "";

type epubmeta = struct {
	dir: str,        // cache-mappen, fx ~/.cache/diya/bog.epub
	title: str,      // altid allokeret
	spine: []str,    // kapitelfiler relativt til dir, i læserækkefølge
};

type htmlstate = struct {
	buf: []u8,
	head: bool,
};

fn meta_free(m: *epubmeta) void = {
	free(m.dir);
	free(m.title);
	strings::freeall(m.spine);
};

// --- små byte-hjælpere (alt er byte-baseret, så UTF-8 er ligegyldigt) ---

fn same(n: []u8, s: str) bool = bytes::equal(n, strings::toutf8(s));

fn isspace(c: u8) bool = c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

fn hexval(c: u8) (u8 | void) = {
	if (c >= 0x30 && c <= 0x39) return c - 0x30;
	if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
	if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
	return;
};

// Værdien af attributten name="..." eller name='...'
fn attr(tag: []u8, name: str) ([]u8 | void) = {
	const n = strings::toutf8(name);
	let i = 0z;
	for (i < len(tag)) {
		const at = match (bytes::index(tag[i..], n)) {
		case let o: size =>
			yield i + o;
		case void =>
			return;
		};
		const end = at + len(n);
		if (at > 0 && isspace(tag[at - 1]) && end + 1 < len(tag)
				&& tag[end] == 0x3D
				&& (tag[end + 1] == 0x22 || tag[end + 1] == 0x27)) {
			const q = tag[end + 1];
			const vstart = end + 2;
			let j = vstart;
			for (j < len(tag) && tag[j] != q) j += 1;
			return tag[vstart..j];
		};
		i = at + 1;
	};
	return;
};

// Tagnavn uden namespace-præfiks (dc:title -> title) og om det er et slut-tag
fn tagname(tag: []u8) ([]u8, bool) = {
	let s = 0z;
	let closing = false;
	if (len(tag) > 0 && tag[0] == 0x2F) {
		closing = true;
		s = 1;
	};
	let e = s;
	for (e < len(tag) && !isspace(tag[e]) && tag[e] != 0x2F) e += 1;
	let n = tag[s..e];
	for (let k = 0z; k < len(n); k += 1) {
		if (n[k] == 0x3A) {
			n = n[k + 1..];
			break;
		};
	};
	return (n, closing);
};

fn pctdecode(s: []u8) str = {
	let out: []u8 = [];
	for (let i = 0z; i < len(s); i += 1) {
		if (s[i] == 0x25 && i + 2 < len(s)) {
			match (hexval(s[i + 1])) {
			case let hi: u8 =>
				match (hexval(s[i + 2])) {
				case let lo: u8 =>
					append(out, hi * 16 + lo)!;
					i += 2;
					continue;
				case void => void;
				};
			case void => void;
			};
		};
		append(out, s[i])!;
	};
	return strings::fromutf8_unsafe(out);
};

fn decode_entity(e: []u8) (rune | void) = {
	if (same(e, "amp")) return '&';
	if (same(e, "lt")) return '<';
	if (same(e, "gt")) return '>';
	if (same(e, "quot")) return '"';
	if (same(e, "apos")) return '\'';
	if (same(e, "nbsp")) return ' ';
	if (same(e, "shy")) return '­';
	if (same(e, "mdash")) return '—';
	if (same(e, "ndash")) return '–';
	if (same(e, "hellip")) return '…';
	if (same(e, "laquo")) return '«';
	if (same(e, "raquo")) return '»';
	if (same(e, "lsquo")) return '‘';
	if (same(e, "rsquo")) return '’';
	if (same(e, "ldquo")) return '“';
	if (same(e, "rdquo")) return '”';
	if (len(e) < 2 || e[0] != 0x23) return;

	let v: u32 = 0;
	if (e[1] == 0x78 || e[1] == 0x58) {
		for (let k = 2z; k < len(e); k += 1) {
			match (hexval(e[k])) {
			case let h: u8 =>
				v = v * 16 + h: u32;
			case void =>
				return;
			};
		};
	} else {
		for (let k = 1z; k < len(e); k += 1) {
			if (e[k] < 0x30 || e[k] > 0x39) return;
			v = v * 10 + (e[k] - 0x30): u32;
		};
	};
	if (v == 0 || v > 0x10FFFF) return;
	return v: rune;
};

fn push_rune(st: *htmlstate, r: rune) void = {
	const v = r: u32;
	if (v < 0x80) {
		append(st.buf, v: u8)!;
	} else if (v < 0x800) {
		append(st.buf, (0xC0 | (v >> 6)): u8)!;
		append(st.buf, (0x80 | (v & 0x3F)): u8)!;
	} else if (v < 0x10000) {
		append(st.buf, (0xE0 | (v >> 12)): u8)!;
		append(st.buf, (0x80 | ((v >> 6) & 0x3F)): u8)!;
		append(st.buf, (0x80 | (v & 0x3F)): u8)!;
	} else {
		append(st.buf, (0xF0 | (v >> 18)): u8)!;
		append(st.buf, (0x80 | ((v >> 12) & 0x3F)): u8)!;
		append(st.buf, (0x80 | ((v >> 6) & 0x3F)): u8)!;
		append(st.buf, (0x80 | (v & 0x3F)): u8)!;
	};
};

fn push_space(st: *htmlstate) void = {
	if (len(st.buf) > 0 && st.buf[len(st.buf) - 1] != 0x20) {
		append(st.buf, 0x20: u8)!;
	};
};

// Tekst mellem tags: saml whitespace, oversæt &entiteter;
fn append_text(st: *htmlstate, seg: []u8) void = {
	for (let i = 0z; i < len(seg); i += 1) {
		const c = seg[i];
		if (isspace(c)) {
			push_space(st);
			continue;
		};
		if (c == 0x26) {
			let semi = i + 1;
			for (semi < len(seg) && semi < i + 12 && seg[semi] != 0x3B) semi += 1;
			if (semi < len(seg) && seg[semi] == 0x3B) {
				match (decode_entity(seg[i + 1..semi])) {
				case let r: rune =>
					if (r == ' ') {
						push_space(st);
					} else {
						push_rune(st, r);
					};
					i = semi;
					continue;
				case void => void;
				};
			};
		};
		append(st.buf, c)!;
	};
};

fn is_block(n: []u8) bool = {
	const blocks: [_]str = [
		"p", "div", "br", "li", "blockquote", "tr", "section", "hr",
		"dd", "dt", "pre", "table", "figcaption", "aside",
	];
	for (let i = 0z; i < len(blocks); i += 1) {
		if (same(n, blocks[i])) return true;
	};
	return false;
};

fn is_heading(n: []u8) bool =
	len(n) == 2 && (n[0] == 0x68 || n[0] == 0x48) && n[1] >= 0x31 && n[1] <= 0x36;

fn html_flush(b: *book, st: *htmlstate) void = {
	const s = strings::trim(strings::fromutf8_unsafe(st.buf));
	if (len(s) > 0) {
		if (st.head && len(s) < 120) {
			add_chunk(b, strings::dup(s)!, kind::HEAD);
		} else {
			add_text(b, s);
		};
	};
	delete(st.buf[..]);
};

// Ét XHTML-kapitel -> afsnit/overskrifter/billeder i bogen.
// base = kapitlets mappe relativt til cachen (fx "OEBPS/Text/")
fn html_to_chunks(b: *book, html: []u8, base: str) void = {
	let st = htmlstate { buf = [], head = false };
	defer free(st.buf);

	let i = match (bytes::index(html, strings::toutf8("<body"))) {
	case let o: size =>
		yield o;
	case void =>
		yield 0z;
	};

	for (i < len(html)) {
		if (html[i] != 0x3C) {
			let j = i;
			for (j < len(html) && html[j] != 0x3C) j += 1;
			append_text(&st, html[i..j]);
			i = j;
			continue;
		};

		// <!-- kommentarer -->
		if (i + 4 <= len(html) && same(html[i..i + 4], "<!--")) {
			match (bytes::index(html[i..], strings::toutf8("-->"))) {
			case let o: size =>
				i += o + 3;
			case void =>
				i = len(html);
			};
			continue;
		};

		const gt = match (bytes::index(html[i..], strings::toutf8(">"))) {
		case let o: size =>
			yield i + o;
		case void =>
			break;
		};
		const tag = html[i + 1..gt];
		i = gt + 1;
		if (len(tag) == 0 || tag[0] == 0x21 || tag[0] == 0x3F) continue;

		const (name, closing) = tagname(tag);

		if (!closing && (same(name, "script") || same(name, "style"))) {
			const endtag = if (same(name, "script")) "</script" else "</style";
			match (bytes::index(html[i..], strings::toutf8(endtag))) {
			case let o: size =>
				const after = i + o;
				match (bytes::index(html[after..], strings::toutf8(">"))) {
				case let g: size =>
					i = after + g + 1;
				case void =>
					i = len(html);
				};
			case void =>
				i = len(html);
			};
			continue;
		};

		if (!closing && (same(name, "img") || same(name, "image"))) {
			match (img_src(tag)) {
			case let src: []u8 =>
				html_flush(b, &st);
				add_chunk(b, resolve(base, src), kind::IMG);
			case void => void;
			};
			continue;
		};

		if (is_heading(name)) {
			html_flush(b, &st);
			st.head = !closing;
		} else if (is_block(name)) {
			html_flush(b, &st);
		};
	};
	html_flush(b, &st);
};

// Pakker EPUB'en ud (kun første gang). Returnerer cache-mappen.
fn epub_dir(name: str) (str | void) = {
	const dir = strings::concat(cachedir, "/", name)!;
	const marker = strings::concat(dir, "/META-INF/container.xml")!;
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
	let cmd = match (exec::cmd("unzip", "-o", "-qq", src, "-d", dir)) {
	case let c: exec::command =>
		yield c;
	case =>
		free(dir);
		return;
	};
	let proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		free(dir);
		return;
	};
	match (exec::wait(&proc)) {
	case exec::status => void;
	case => void;
	};
	if (!os::exists(marker)) {
		free(dir);
		return;
	};
	return dir;
};

fn epub_meta(name: str) (epubmeta | void) = {
	const dir = match (epub_dir(name)) {
	case let d: str =>
		yield d;
	case void =>
		return;
	};
	let m = epubmeta { dir = dir, title = strings::dup("")!, spine = [] };
	let ok = false;
	defer if (!ok) meta_free(&m);

	const cpath = strings::concat(dir, "/META-INF/container.xml")!;
	defer free(cpath);
	const container = match (readfile(cpath)) {
	case let s: str =>
		yield s;
	case void =>
		return;
	};
	defer free(container);
	const rel = match (attr(strings::toutf8(container), "full-path")) {
	case let r: []u8 =>
		yield r;
	case void =>
		return;
	};
	const opfrel = pctdecode(rel);
	defer free(opfrel);

	// mappen OPF-filen ligger i, med afsluttende /
	const ob = strings::toutf8(opfrel);
	let cut = 0z;
	for (let k = 0z; k < len(ob); k += 1) {
		if (ob[k] == 0x2F) cut = k + 1;
	};
	const opfdir = strings::fromutf8_unsafe(ob[..cut]);

	const opfpath = strings::concat(dir, "/", opfrel)!;
	defer free(opfpath);
	const opf = match (readfile(opfpath)) {
	case let s: str =>
		yield s;
	case void =>
		return;
	};
	defer free(opf);
	const data = strings::toutf8(opf);

	let ids: [][]u8 = [];
	defer free(ids);
	let hrefs: [][]u8 = [];
	defer free(hrefs);
	let refs: [][]u8 = [];
	defer free(refs);

	let i = 0z;
	for (i < len(data)) {
		const lt = match (bytes::index(data[i..], strings::toutf8("<"))) {
		case let o: size =>
			yield i + o;
		case void =>
			break;
		};
		const gt = match (bytes::index(data[lt..], strings::toutf8(">"))) {
		case let o: size =>
			yield lt + o;
		case void =>
			break;
		};
		const tag = data[lt + 1..gt];
		i = gt + 1;
		const (tn, closing) = tagname(tag);
		if (closing) continue;

		if (same(tn, "item")) {
			match (attr(tag, "id")) {
			case let id: []u8 =>
				match (attr(tag, "href")) {
				case let h: []u8 =>
					append(ids, id)!;
					append(hrefs, h)!;
				case void => void;
				};
			case void => void;
			};
		} else if (same(tn, "itemref")) {
			match (attr(tag, "idref")) {
			case let r: []u8 =>
				append(refs, r)!;
			case void => void;
			};
		} else if (same(tn, "title") && len(m.title) == 0) {
			let e = i;
			for (e < len(data) && data[e] != 0x3C) e += 1;
			let st = htmlstate { buf = [], head = false };
			append_text(&st, data[i..e]);
			free(m.title);
			m.title = strings::dup(strings::trim(strings::fromutf8_unsafe(st.buf)))!;
			free(st.buf);
		};
	};

	for (let r = 0z; r < len(refs); r += 1) {
		for (let j = 0z; j < len(ids); j += 1) {
			if (!bytes::equal(ids[j], refs[r])) continue;
			let h = hrefs[j];
			for (let k = 0z; k < len(h); k += 1) {
				if (h[k] == 0x23) {
					h = h[..k];
					break;
				};
			};
			const hrel = pctdecode(h);
			append(m.spine, strings::concat(opfdir, hrel)!)!;
			free(hrel);
			break;
		};
	};
	ok = true;
	return m;
};

fn load_epub(name: str) (book | void) = {
	let m = match (epub_meta(name)) {
	case let m: epubmeta =>
		yield m;
	case void =>
		return;
	};
	defer meta_free(&m);

	let b = book { chunks = [], kinds = [], pages = [] };
	for (let i = 0z; i < len(m.spine); i += 1) {
		const full = strings::concat(m.dir, "/", m.spine[i])!;
		defer free(full);
		match (readfile(full)) {
		case let s: str =>
			const html = strings::toutf8(s);
			match (viewport(html)) {
			case let wh: (size, size) =>
				// fixed layout: hele siden vises som den er (tekstlag + billede)
				add_chunk(&b, fmt::asprintf("{} {} {}", wh.0, wh.1, m.spine[i])!, kind::PAGE);
			case void =>
				html_to_chunks(&b, html, dirname(m.spine[i]));
			};
			free(s);
		case void => void;
		};
	};
	if (len(b.chunks) == 0) {
		add_chunk(&b, strings::dup("(Diya kunne ikke finde tekst eller billeder i denne EPUB)")!, kind::TEXT);
	};
	paginate(&b);
	return b;
};

// Pæn titel: EPUB-titlen fra OPF, ellers filnavnet. Kalderen frigør.
fn display_title(name: str) str = {
	if (strings::hassuffix(name, ".epub")) {
		match (epub_meta(name)) {
		case let m: epubmeta =>
			let mm = m;
			const t = strings::dup(mm.title)!;
			meta_free(&mm);
			if (len(t) > 0) return t;
			free(t);
		case void => void;
		};
	};
	let t = strings::trimsuffix(name, ".txt");
	t = strings::trimsuffix(t, ".md");
	t = strings::trimsuffix(t, ".epub");
    t = strings::trimsuffix(t, ".cbz");
	t = strings::trimsuffix(t, ".cbr");
	return strings::replace(t, "_", " ")!;
};

// "OEBPS/Text/kap1.xhtml" -> "OEBPS/Text/" (lånt, ingen allokering)
fn dirname(p: str) str = {
	const b = strings::toutf8(p);
	let cut = 0z;
	for (let k = 0z; k < len(b); k += 1) {
		if (b[k] == 0x2F) cut = k + 1;
	};
	return strings::fromutf8_unsafe(b[..cut]);
};

// Billedets kilde: <img src> eller SVG <image xlink:href / href>
fn img_src(tag: []u8) ([]u8 | void) = {
	let s: []u8 = [];
	match (attr(tag, "src")) {
	case let v: []u8 =>
		s = v;
	case void =>
		match (attr(tag, "xlink:href")) {
		case let v: []u8 =>
			s = v;
		case void =>
			match (attr(tag, "href")) {
			case let v: []u8 =>
				s = v;
			case void =>
				return;
			};
		};
	};
	if (len(s) == 0) return;
	if (len(s) >= 5 && same(s[..5], "data:")) return;
	if (len(s) >= 4 && same(s[..4], "http")) return;
	return s;
};

// Løser "../Images/p1.jpg" mod "OEBPS/Text/" -> "OEBPS/Images/p1.jpg"
fn resolve(base: str, src: []u8) str = {
	let raw = src;
	for (let k = 0z; k < len(raw); k += 1) {
		if (raw[k] == 0x23 || raw[k] == 0x3F) {
			raw = raw[..k];
			break;
		};
	};
	const s = pctdecode(raw);
	defer free(s);

	let segs: []str = [];
	defer free(segs);
	if (!strings::hasprefix(s, "/")) {
		let t1 = strings::tokenize(base, "/");
		for (true) {
			const p = match (strings::next_token(&t1)) {
			case let p: str =>
				yield p;
			case =>
				break;
			};
			if (len(p) > 0) append(segs, p)!;
		};
	};
	let t2 = strings::tokenize(s, "/");
	for (true) {
		const p = match (strings::next_token(&t2)) {
		case let p: str =>
			yield p;
		case =>
			break;
		};
		if (len(p) == 0 || p == ".") continue;
		if (p == "..") {
			if (len(segs) > 0) delete(segs[len(segs) - 1]);
			continue;
		};
		append(segs, p)!;
	};
	return strings::join("/", segs...)!;
};

fn mimetype(p: str) str = {
	const exts: [_]str = [".jpg", ".JPG", ".jpeg", ".JPEG", ".png", ".PNG",
		".gif", ".GIF", ".webp", ".svg", ".SVG",
		".xhtml", ".html", ".htm", ".css", ".js", ".xml",
		".otf", ".ttf", ".woff2", ".woff", ".OTF", ".TTF"];
	const types: [_]str = ["image/jpeg", "image/jpeg", "image/jpeg", "image/jpeg",
		"image/png", "image/png", "image/gif", "image/gif", "image/webp",
		"image/svg+xml", "image/svg+xml",
		"application/xhtml+xml", "text/html; charset=utf-8", "text/html; charset=utf-8",
		"text/css", "text/javascript", "application/xml",
		"font/otf", "font/ttf", "font/woff2", "font/woff", "font/otf", "font/ttf"];
	for (let i = 0z; i < len(exts); i += 1) {
		if (strings::hassuffix(p, exts[i])) return types[i];
	};
	return "application/octet-stream";
};

// Skriver en sti URL-kodet (kun a-z A-Z 0-9 / . _ - står frit)
fn urlenc(h: io::handle, s: str) void = {
	const hx = strings::toutf8("0123456789ABCDEF");
	const b = strings::toutf8(s);
	for (let i = 0z; i < len(b); i += 1) {
		const c = b[i];
		const safe = (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A)
			|| (c >= 0x61 && c <= 0x7A)
			|| c == 0x2F || c == 0x2E || c == 0x5F || c == 0x2D;
		if (safe) {
			putb(h, b[i..i + 1]);
			continue;
		};
		let out: [3]u8 = [0x25, hx[(c >> 4): size], hx[(c & 0x0F): size]];
		putb(h, out[..]);
	};
};

// GET /img?bog=N&f=<sti i EPUB-cachen>
fn page_img(c: io::handle, q: str) void = {
	const books = list_books();
	defer strings::freeall(books);
	const bi = match (qnum(q, "bog")) {
	case let n: size =>
		yield n;
	case void =>
		yield len(books);
	};
	const f = match (qget(q, "f")) {
	case let f: str =>
		yield f;
	case void =>
		yield "";
	};
	const rel = pctdecode(strings::toutf8(f));
	defer free(rel);
	if (bi >= len(books) || len(rel) == 0 || strings::hasprefix(rel, "/")
			|| bytes::index(strings::toutf8(rel), strings::toutf8("..")) is size) {
		page_notfound(c);
		return;
	};

	serve_cached(c, books[bi], rel);
};

// GET /epub/<bog>/<sti> — EPUB'ens egne filer, så relative stier
// (../Images, ../Styles, skrifttyper) i fixed-layout-sider bare virker
fn page_epubfile(c: io::handle, path: str) void = {
	const rest = strings::trimprefix(path, "/epub/");
	const (num, enc) = strings::cut(rest, "/");
	const books = list_books();
	defer strings::freeall(books);
	const bi = match (strconv::stoz(num)) {
	case let n: size =>
		yield n;
	case =>
		yield len(books);
	};
	const rel = pctdecode(strings::toutf8(enc));
	defer free(rel);
	if (bi >= len(books) || len(rel) == 0 || strings::hasprefix(rel, "/")
			|| bytes::index(strings::toutf8(rel), strings::toutf8("..")) is size) {
		page_notfound(c);
		return;
	};
	serve_cached(c, books[bi], rel);
};

fn serve_cached(c: io::handle, name: str, rel: str) void = {
	const p = strings::concat(cachedir, "/", name, "/", rel)!;
	defer free(p);
	const data = match (readbytes(p)) {
	case let d: []u8 =>
		yield d;
	case void =>
		page_notfound(c);
		return;
	};
	defer free(data);
	putf(c, "HTTP/1.1 200 OK\r\nContent-Type: {}\r\nContent-Length: {}\r\n"
		"Cache-Control: max-age=86400\r\nConnection: close\r\n\r\n",
		mimetype(rel), len(data));
	putb(c, data);
};

// Tal efter "key=" i fx "width=1200, height=1800"
fn numafter(s: []u8, key: str) (size | void) = {
	const at = match (bytes::index(s, strings::toutf8(key))) {
	case let o: size =>
		yield o + len(key);
	case void =>
		return;
	};
	let i = at;
	for (i < len(s) && (isspace(s[i]) || s[i] == 0x3D)) i += 1;
	let v = 0z;
	let any = false;
	for (i < len(s) && s[i] >= 0x30 && s[i] <= 0x39) {
		v = v * 10 + (s[i] - 0x30): size;
		any = true;
		i += 1;
	};
	if (!any || v == 0) return;
	return v;
};

// <meta name="viewport" content="width=1200, height=1800"> -> (1200, 1800)
fn viewport(html: []u8) ((size, size) | void) = {
	const at = match (bytes::index(html, strings::toutf8("viewport"))) {
	case let o: size =>
		yield o;
	case void =>
		return;
	};
	let lt = at;
	for (lt > 0 && html[lt] != 0x3C) lt -= 1;
	let gt = at;
	for (gt < len(html) && html[gt] != 0x3E) gt += 1;
	const tag = html[lt..gt];
	const content = match (attr(tag, "content")) {
	case let v: []u8 =>
		yield v;
	case void =>
		return;
	};
	const w = match (numafter(content, "width")) {
	case let n: size =>
		yield n;
	case void =>
		return;
	};
	const h = match (numafter(content, "height")) {
	case let n: size =>
		yield n;
	case void =>
		return;
	};
	return (w, h);
};
