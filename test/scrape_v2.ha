use fmt;
use io;
use os;
use os::exec;
use strings;

fn html_decode(s: str) str = {
	// Simpel HTML entity decoder for ø, æ, å
	let r = strings::replace(s, "&#230;", "æ")!;
	let r2 = strings::replace(r, "&#248;", "ø")!; free(r);
	let r3 = strings::replace(r2, "&#229;", "å")!; free(r2);
	let r4 = strings::replace(r3, "&#216;", "Ø")!; free(r3);
	let r5 = strings::replace(r4, "&#198;", "Æ")!; free(r4);
	let r6 = strings::replace(r5, "&#197;", "Å")!; free(r5);
	let r7 = strings::replace(r6, "&amp;", "&")!; free(r6);
	return r7;
};

export fn main() void = {
	fmt::println("=== Kosmorama Movie Scraper ===")!;
	fmt::println("")!;

	let args: []str = alloc([], 6)!;
	defer free(args);
	append(args, "curl")!;
	append(args, "-s")!;
	append(args, "--max-time")!;
	append(args, "15")!;
	append(args, "-A")!;
	append(args, "Mozilla/5.0 hpo-shifu")!;
	append(args, "https://www.kosmorama6100.dk/")!;

	const cmd = match (exec::cmd("curl", args[1..]...)) {
	case let c: exec::command => yield c;
	case => return;
	};
	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case => return;
	};
	io::close(pipe.1)!;
	static let buf: [262144]u8 = [0...];
	let total: size = 0;
	for (true) {
		const n = match (io::read(pipe.0, buf[total..])) {
		case let nn: size => yield nn;
		case io::EOF => break;
		case => break;
		};
		if (n == 0) break;
		total += n;
		if (total >= len(buf)) break;
	};
	io::close(pipe.0)!;
	exec::wait(&proc)!;

	const html = strings::fromutf8(buf[..total])!;

	// Find alle alt="<film>_poster" matches
	let pos = 0z;
	let movies: []str = alloc([], 30)!;
	defer free(movies);

	for (true) {
		const rest = strings::sub(html, pos, strings::end);
		const idx = match (strings::index(rest, "alt=\"")) {
		case let n: size => yield n;
		case void => break;
		};
		const after = strings::sub(rest, idx + 5, strings::end);
		const end = match (strings::index(after, "\"")) {
		case let n: size => yield n;
		case void => break;
		};
		const alt_text = strings::sub(after, 0, end);

		// Kun film-posters (ikke generic _slide_poster eller andre)
		if (strings::hassuffix(alt_text, "_poster") && alt_text != "_slide_poster") {
			const title_raw = strings::sub(alt_text, 0, len(alt_text) - 7);
			const title = html_decode(title_raw);
			// Dedupe
			let already = false;
			for (let i = 0z; i < len(movies); i += 1) {
				if (movies[i] == title) {
					already = true;
					break;
				};
			};
			if (!already) {
				append(movies, title)!;
			};
		};
		pos = pos + idx + 5 + end;
	};

	fmt::printfln("🎬 Found {} unique movies playing at Kosmorama Haderslev:", len(movies))!;
	fmt::println("")!;
	for (let i = 0z; i < len(movies); i += 1) {
		fmt::printfln("  • {}", movies[i])!;
	};
};
