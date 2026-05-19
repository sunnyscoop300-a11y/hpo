use fmt;
use io;
use os;
use os::exec;
use strings;

export fn main() void = {
	fmt::println("=== Test: Scrape Kosmorama for film ===")!;
	fmt::println("")!;

	// Step 1: Curl Kosmorama dagens program
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
	case =>
		fmt::println("✗ Curl command failed")!;
		return;
	};
	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case =>
		fmt::println("✗ Curl start failed")!;
		return;
	};
	io::close(pipe.1)!;
	static let buf: [262144]u8 = [0...]; // 256KB
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

	fmt::printfln("✓ Read {} bytes from Kosmorama", total)!;

	const html = strings::fromutf8(buf[..total])!;

	// Step 2: Find film-titler i HTML
	// Vi så fra web_fetch at film vises som "###### <filmnavn>"
	// Lad os tælle hvor mange gange "filmdetaljer?movieId=" findes
	let pos = 0z;
	let count = 0;
	fmt::println("")!;
	fmt::println("=== Søger efter movie IDs ===")!;
	for (true) {
		const rest = strings::sub(html, pos, strings::end);
		const idx = match (strings::index(rest, "filmdetaljer?movieId=")) {
		case let n: size => yield n;
		case void => break;
		};
		count += 1;
		// Find ID
		const after = strings::sub(rest, idx + 21, strings::end);
		const end = match (strings::index(after, "\"")) {
		case let n: size => yield n;
		case void => break;
		};
		const movie_id = strings::sub(after, 0, end);
		if (count <= 10) {
			fmt::printfln("  Movie ID #{}: {}", count, movie_id)!;
		};
		pos = pos + idx + 21 + end;
	};
	fmt::printfln("")!;
	fmt::printfln("✓ Found {} movie ID references in HTML", count)!;

	// Step 3: Forsøg at finde alt text fra poster-billeder (filmnavne)
	fmt::println("")!;
	fmt::println("=== Søger efter movie posters (alt-tekst) ===")!;
	pos = 0z;
	let pcount = 0;
	for (true) {
		const rest = strings::sub(html, pos, strings::end);
		const idx = match (strings::index(rest, "poster.ebillet.dk")) {
		case let n: size => yield n;
		case void => break;
		};
		pcount += 1;
		// Find filename
		const after = strings::sub(rest, idx + 18, strings::end);
		const end = match (strings::index(after, ".")) {
		case let n: size => yield n;
		case void => break;
		};
		const poster = strings::sub(after, 0, end);
		if (pcount <= 10) {
			fmt::printfln("  Poster #{}: {}", pcount, poster)!;
		};
		pos = pos + idx + 18 + end;
	};
	fmt::printfln("")!;
	fmt::printfln("✓ Found {} poster references", pcount)!;
};
