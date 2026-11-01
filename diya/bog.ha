// Bøger: find, indlæs, del op i afsnit og sider.
use fs;
use io;
use os;
use strings;

// Ca. så mange bytes tekst pr. side
def PAGE_BYTES: size = 1800;

type kind = enum u8 {
	TEXT,
	HEAD,  // overskrift
	IMG,   // billede (sti relativt til EPUB-cachen)
	PAGE,  // fixed-layout side: "bredde højde sti"
};

type book = struct {
	chunks: []str,  // afsnit, overskrifter eller billedstier
	kinds: []kind,
	pages: []size,  // første chunk på hver side
};

fn is_book(name: str) bool =
	strings::hassuffix(name, ".txt") || strings::hassuffix(name, ".md")
	|| strings::hassuffix(name, ".epub");

// Sorteret liste af bøger i bogmappen. Kalderen frigør med strings::freeall.
fn list_books() []str = {
	let out: []str = [];
	const ents = match (os::readdir(bookdir)) {
	case let e: []fs::dirent =>
		yield e;
	case =>
		return out;
	};
	defer fs::dirents_free(ents);

	for (let i = 0z; i < len(ents); i += 1) {
		const n = ents[i].name;
		if (strings::hasprefix(n, ".") || !is_book(n)) continue;
		append(out, strings::dup(n)!)!;
	};

	// indsætningssortering — bogreoler er ikke så lange
	for (let i = 1z; i < len(out); i += 1) {
		let j = i;
		for (j > 0 && strings::compare(out[j - 1], out[j]) > 0) {
			const t = out[j];
			out[j] = out[j - 1];
			out[j - 1] = t;
			j -= 1;
		};
	};
	return out;
};

fn readbytes(p: str) ([]u8 | void) = {
	const f = match (os::open(p)) {
	case let f: io::file =>
		yield f;
	case =>
		return;
	};
	defer closef(f);
	match (io::drain(f)) {
	case let d: []u8 =>
		return d;
	case =>
		return;
	};
};

fn readfile(p: str) (str | void) = {
	const data = match (readbytes(p)) {
	case let d: []u8 =>
		yield d;
	case void =>
		return;
	};
	match (strings::fromutf8(data)) {
	case let s: str =>
		return s;
	case =>
		free(data);
		return;
	};
};

fn looks_like_heading(s: str) bool = {
	if (len(s) > 70) return false;
	const pre: [_]str = [
		"KAPITEL", "Kapitel", "CHAPTER", "Chapter",
		"DEL ", "Del ", "PART ", "Part ", "BOG ", "BOOK ",
		"PROLOG", "Prolog", "EPILOG", "Epilog",
	];
	for (let i = 0z; i < len(pre); i += 1) {
		if (strings::hasprefix(s, pre[i])) return true;
	};
	return false;
};

fn add_chunk(b: *book, s: str, k: kind) void = {
	append(b.chunks, s)!;
	append(b.kinds, k)!;
};

// Deler et langt afsnit ved mellemrum så intet afsnit er større end en side.
fn add_text(b: *book, s: str) void = {
	const bs = strings::toutf8(s);
	let start = 0z;
	for (len(bs) - start > PAGE_BYTES) {
		let cut = start + PAGE_BYTES;
		for (cut > start && bs[cut] != 0x20) cut -= 1;
		if (cut == start) {
			// intet mellemrum: gå frem til en hel UTF-8-tegngrænse
			cut = start + PAGE_BYTES;
			for (cut < len(bs) && (bs[cut] & 0xC0) == 0x80) cut += 1;
		};
		add_chunk(b, strings::dup(strings::fromutf8_unsafe(bs[start..cut]))!, kind::TEXT);
		start = cut;
		if (start < len(bs) && bs[start] == 0x20) start += 1;
	};
	if (start < len(bs)) {
		add_chunk(b, strings::dup(strings::fromutf8_unsafe(bs[start..]))!, kind::TEXT);
	};
};

fn flush_para(b: *book, para: []str) void = {
	if (len(para) == 0) return;
	const joined = strings::join(" ", para...)!;
	if (len(para) == 1 && looks_like_heading(joined)) {
		add_chunk(b, joined, kind::HEAD);
		return;
	};
	add_text(b, joined);
	free(joined);
};

fn load_book(name: str) (book | void) = {
	if (strings::hassuffix(name, ".epub")) return load_epub(name);

	const p = strings::concat(bookdir, "/", name)!;
	defer free(p);
	const text = match (readfile(p)) {
	case let s: str =>
		yield s;
	case void =>
		return;
	};
	defer free(text);

	// Skær Project Gutenbergs licens-hoved og -hale væk
	let body = text;
	const (_, post) = strings::cut(body, "*** START OF");
	if (len(post) > 0) {
		const (_, after) = strings::cut(post, "\n");
		body = after;
	};
	const (content, _) = strings::cut(body, "*** END OF");
	body = content;

	let b = book { chunks = [], kinds = [], pages = [] };
	const md = strings::hassuffix(name, ".md");
	let para: []str = [];
	defer free(para);

	let tok = strings::tokenize(body, "\n");
	for (true) {
		const line = match (strings::next_token(&tok)) {
		case let l: str =>
			yield strings::trim(l);
		case =>
			break;
		};
		if (len(line) == 0) {
			flush_para(&b, para);
			delete(para[..]);
			continue;
		};
		if (md && strings::hasprefix(line, "#")) {
			flush_para(&b, para);
			delete(para[..]);
			const h = strings::trim(strings::ltrim(line, '#'));
			add_chunk(&b, strings::dup(h)!, kind::HEAD);
			continue;
		};
		append(para, line)!;
	};
	flush_para(&b, para);

	paginate(&b);
	return b;
};

// Overskrifter og billeder starter altid en ny side; et billede fylder en hel side.
fn paginate(b: *book) void = {
	let acc = 0z;
	for (let i = 0z; i < len(b.chunks); i += 1) {
		const k = b.kinds[i];
		const n = if (k == kind::IMG || k == kind::PAGE) PAGE_BYTES
			else len(b.chunks[i]);
		const newpage = i == 0
			|| (acc > 0 && acc + n > PAGE_BYTES)
			|| (acc > 0 && k == kind::HEAD);
		if (newpage) {
			append(b.pages, i)!;
			acc = 0;
		};
		acc += n;
	};
	if (len(b.pages) == 0) append(b.pages, 0z)!;
};

// Chunks [start, end) for side p
fn page_range(b: *book, p: size) (size, size) = {
	const start = b.pages[p];
	const end = if (p + 1 < len(b.pages)) b.pages[p + 1] else len(b.chunks);
	return (start, end);
};

fn book_free(b: *book) void = {
	strings::freeall(b.chunks);
	free(b.kinds);
	free(b.pages);
};
