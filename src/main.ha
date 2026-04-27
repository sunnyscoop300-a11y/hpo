use fmt;
use io;
use os;
use os::exec;
use strings;
use time;
use fs;

def VERSION = "1.4.1";

def C_RESET   = "\x1b[0m";
def C_CYAN    = "\x1b[36m";
def C_GREEN   = "\x1b[32m";
def C_YELLOW  = "\x1b[33m";
def C_RED     = "\x1b[31m";
def C_BOLD    = "\x1b[1m";
def C_MAGENTA = "\x1b[35m";
def C_BLUE    = "\x1b[34m";
def C_DIM     = "\x1b[2m";

fn tiger_quote() str = {
	const quotes: [_]str = [
		"Finally! A warrior worthy of my time.",
		"There are no accidents.",
		"One often meets his destiny on the road he takes to avoid it.",
		"Your story may not have such a happy beginning, but that does not make you who you are.",
		"Anything is possible when you have inner peace.",
		"You must believe.",
		"The mark of a true warrior is being able to falcon punch at will.",
		"I have been trained by the greatest kung fu teacher in all of China.",
	];
	const t = time::now(time::clock::MONOTONIC);
	const idx = (t.sec: size + t.nsec: size) % len(quotes);
	return quotes[idx];
};

type opts = struct {
	url:     str,
	output:  str,
	resume:  bool,
	rate:    str,
	agent:   str,
	seed:    str,
	code:    str,
	lock:    str,
	verbose: bool,
	quiet:   bool,
	nocolor: bool,
};

fn cprint(color: str, tag: str, msg: str, nc: bool) void = {
	if (nc) {
		fmt::printfln("[{}] {}", tag, msg)!;
	} else {
		fmt::printfln("{}{}[{}]{} {}", color, C_BOLD, tag, C_RESET, msg)!;
	};
};

fn is_magnet(url: str) bool = {
	return strings::hasprefix(url, "magnet:?");
};

fn is_rooster(url: str) bool = {
	return strings::hasprefix(url, "rooster:?xt=AES256:");
};

fn is_gdrive(url: str) bool = {
	return strings::hasprefix(url, "https://drive.google.com/");
};

fn gdrive_file_id(url: str) str = {
	const prefix = "https://drive.google.com/file/d/";
	if (strings::hasprefix(url, prefix)) {
		const rest = strings::sub(url, len(prefix), strings::end);
		const id_end = match (strings::index(rest, '/')) {
		case let i: size =>
			yield i;
		case void =>
			yield match (strings::index(rest, '?')) {
			case let i: size =>
				yield i;
			case void =>
				yield len(rest);
			};
		};
		return strings::sub(rest, 0, id_end);
	};
	const idparam = "id=";
	const idx = match (strings::index(url, idparam)) {
	case let i: size =>
		yield i;
	case void =>
		return "";
	};
	const rest = strings::sub(url, idx + len(idparam), strings::end);
	const id_end = match (strings::index(rest, '&')) {
	case let i: size =>
		yield i;
	case void =>
		yield len(rest);
	};
	return strings::sub(rest, 0, id_end);
};

fn filename_from_url(url: str) str = {
	const idx = match (strings::rindex(url, '/')) {
	case let i: size =>
		yield i;
	case void =>
		return "download";
	};
	const part = strings::sub(url, idx + 1, strings::end);
	if (len(part) == 0) {
		return "download";
	};
	const part2 = match (strings::index(part, '?')) {
	case let i: size =>
		yield strings::sub(part, 0, i);
	case void =>
		yield part;
	};
	const part3 = match (strings::index(part2, '#')) {
	case let i: size =>
		yield strings::sub(part2, 0, i);
	case void =>
		yield part2;
	};
	if (len(part3) == 0) {
		return "download";
	};
	return part3;
};

fn default_output(url: str) str = {
	const home = match (os::getenv("HOME")) {
	case let s: str =>
		yield s;
	case void =>
		yield "/tmp";
	};
	if (is_magnet(url)) {
		static let mbuf: [512]u8 = [0...];
		return fmt::bsprintf(mbuf, "{}/Downloads", home)!;
	};
	if (is_gdrive(url)) {
		static let gbuf: [512]u8 = [0...];
		return fmt::bsprintf(gbuf, "{}/Downloads", home)!;
	};
	const name = filename_from_url(url);
	static let buf: [512]u8 = [0...];
	return fmt::bsprintf(buf, "{}/Downloads/{}", home, name)!;
};

fn check_tool(name: str) bool = {
	const cmd = match (exec::cmd(name, "--version")) {
	case let c: exec::command =>
		yield c;
	case exec::nocmd =>
		return false;
	case =>
		return false;
	};
	exec::nullstd(&cmd)!;
	const proc = match (exec::start(&cmd)) {
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
	case exec::exited =>
		return true;
	case =>
		return false;
	};
};

fn check_tool_help(name: str) bool = {
	const cmd = match (exec::cmd(name, "--help")) {
	case let c: exec::command =>
		yield c;
	case exec::nocmd =>
		return false;
	case =>
		return false;
	};
	exec::nullstd(&cmd)!;
	const proc = match (exec::start(&cmd)) {
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
	case exec::exited =>
		return true;
	case =>
		return false;
	};
};

fn run_cmd(args: []str, nc: bool) bool = {
	const cmd = match (exec::cmd(args[0], args[1..]...)) {
	case let c: exec::command =>
		yield c;
	case exec::nocmd =>
		cprint(C_RED, "ERR", "command not found in PATH", nc);
		os::exit(1);
	case =>
		cprint(C_RED, "ERR", "failed to build command", nc);
		os::exit(1);
	};
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		cprint(C_RED, "ERR", "failed to start process", nc);
		os::exit(1);
	};
	const st = match (exec::wait(&proc)) {
	case let s: exec::status =>
		yield s;
	case =>
		cprint(C_RED, "ERR", "failed to wait for process", nc);
		os::exit(1);
	};
	fmt::println("")!;
	match (exec::exit(&st)) {
	case let e: exec::exited =>
		if (e != 0) {
			cprint(C_RED, "ERR", "process exited with error", nc);
			return false;
		};
		return true;
	case =>
		cprint(C_RED, "ERR", "process exited with error", nc);
		return false;
	};
};

fn format_size(bytes: size) str = {
	static let sbuf: [64]u8 = [0...];
	if (bytes >= 1073741824) {
		return fmt::bsprintf(sbuf, "{}.{} GB",
			bytes / 1073741824,
			(bytes % 1073741824) / 107374182)!;
	} else if (bytes >= 1048576) {
		return fmt::bsprintf(sbuf, "{}.{} MB",
			bytes / 1048576,
			(bytes % 1048576) / 104857)!;
	} else if (bytes >= 1024) {
		return fmt::bsprintf(sbuf, "{}.{} KB",
			bytes / 1024,
			(bytes % 1024) / 102)!;
	};
	return fmt::bsprintf(sbuf, "{} B", bytes)!;
};

fn format_speed(bps: size) str = {
	static let spbuf: [64]u8 = [0...];
	if (bps >= 1048576) {
		return fmt::bsprintf(spbuf, "{}.{} MB/s",
			bps / 1048576,
			(bps % 1048576) / 104857)!;
	} else if (bps >= 1024) {
		return fmt::bsprintf(spbuf, "{}.{} KB/s",
			bps / 1024,
			(bps % 1024) / 102)!;
	};
	return fmt::bsprintf(spbuf, "{} B/s", bps)!;
};

fn get_content_length(url: str, ua: str) size = {
	const cmd = match (exec::cmd("curl", "-g", "-sI", "-L", "--max-time", "5", "-A", ua, url)) {
	case let c: exec::command =>
		yield c;
	case =>
		return 0;
	};

	const pipefd = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipefd.1)!;
	exec::addfile(&cmd, os::stderr_file, exec::nullfd)!;

	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		io::close(pipefd.0)!;
		io::close(pipefd.1)!;
		return 0;
	};
	io::close(pipefd.1)!;

	let buf: [4096]u8 = [0...];
	let total = 0z;
	for (true) {
		const n = match (io::read(pipefd.0, buf[total..])) {
		case let n: size =>
			yield n;
		case io::EOF =>
			break;
		case =>
			break;
		};
		total += n;
		if (total >= len(buf) - 1) break;
	};
	io::close(pipefd.0)!;
	exec::wait(&proc)!;

	const output = strings::fromutf8(buf[..total])!;
	const lines = strings::split(output, "\n")!;
	defer free(lines);
	for (let line .. lines) {
		if (strings::hasprefix(line, "Content-Length:") || strings::hasprefix(line, "content-length:")) {
			const val = strings::sub(line, 16, strings::end);
			const val2 = strings::trim(val);
			let result = 0z;
			const bytes_val = strings::toutf8(val2);
			for (let b .. bytes_val) {
				if (b >= '0' && b <= '9') {
					result = result * 10 + (b - '0'): size;
				};
			};
			return result;
		};
	};
	return 0;
};

fn draw_progress(downloaded: size, total: size, elapsed_secs: size, nc: bool) void = {
	const bar_width = 30z;
	const pct = if (total > 0) (downloaded * 100) / total else 0z;
	const filled = if (total > 0) (downloaded * bar_width) / total else 0z;
	const speed = if (elapsed_secs > 0) downloaded / elapsed_secs else 0z;
	const eta = if (speed > 0 && total > downloaded)
		(total - downloaded) / speed
	else
		0z;
	const eta_m = eta / 60;
	const eta_s = eta % 60;

	if (nc) {
		fmt::printf("\r  [{}%] {}/{} | {} | ETA {}:{}   ",
			pct, format_size(downloaded), format_size(total),
			format_speed(speed), eta_m, eta_s)!;
	} else {
		fmt::printf("\r  {}[{}", C_CYAN, C_RESET)!;
		for (let j = 0z; j < bar_width; j += 1) {
			if (j < filled) {
				fmt::printf("{}={}", C_GREEN, C_RESET)!;
			} else if (j == filled) {
				fmt::printf("{}}}{}", C_RED, C_RESET)!;
			} else if (j == filled + 1) {
				fmt::printf("{}~{}", C_RED, C_RESET)!;
			} else if (j == filled + 2) {
				fmt::printf("{}>{}", C_RED, C_RESET)!;
			} else {
				fmt::printf("{}·{}", C_DIM, C_RESET)!;
			};
		};
		fmt::printf("{}]{} ", C_CYAN, C_RESET)!;
		fmt::printf("{}{}{}%{} ", C_BOLD, C_GREEN, pct, C_RESET)!;
		fmt::printf("{}{}{} ", C_YELLOW, format_speed(speed), C_RESET)!;
		fmt::printf("{}{}/{}{} ", C_DIM, format_size(downloaded), format_size(total), C_RESET)!;
		fmt::printf("{}ETA {}:{}{}  ",
			C_MAGENTA, eta_m, eta_s, C_RESET)!;
	};
};

fn get_file_size(path: str) size = {
	const st = match (os::stat(path)) {
	case let s: fs::filestat =>
		yield s;
	case =>
		return 0;
	};
	return st.sz: size;
};

// Encrypt a URL into a rooster link
fn rooster_encrypt(url: str, code: str, nc: bool) void = {
	if (!check_tool("openssl")) {
		cprint(C_RED, "ERR", "openssl not found! Required for Rooster links.", nc);
		os::exit(1);
	};

	if (!nc) fmt::print(C_CYAN)!;
	fmt::println("
  _    _  _____   ___  
 | |  | ||  __ \\ / _ \\ 
 | |__| || |__) | | | |
 |  __  ||  ___/| | | |
 | |  | || |    | |_| |
 |_|  |_||_|     \\___/ 

  Rooster Link Generator
")!;
	if (!nc) fmt::print(C_RESET)!;

	cprint(C_YELLOW, "HPO", "Encrypting URL with AES-256-CBC...", nc);
	if (!nc) fmt::print(C_YELLOW)!;
	fmt::printfln("  URL:  {}", url)!;
	if (!nc) fmt::print(C_RESET)!;

	const pipecmd = fmt::asprintf(
		"printf '%s' '{}' | openssl enc -aes-256-cbc -a -A -salt -pbkdf2 -pass pass:'{}'",
		url, code,
	)!;
	defer free(pipecmd);

	const cmd = match (exec::cmd("sh", "-c", pipecmd)) {
	case let c: exec::command =>
		yield c;
	case =>
		cprint(C_RED, "ERR", "failed to build encryption command", nc);
		os::exit(1);
	};

	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;

	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		cprint(C_RED, "ERR", "failed to start openssl", nc);
		os::exit(1);
	};
	io::close(pipe.1)!;

	static let outbuf: [4096]u8 = [0...];
	const n = match (io::read(pipe.0, outbuf)) {
	case let n: size =>
		yield n;
	case =>
		cprint(C_RED, "ERR", "failed to read openssl output", nc);
		os::exit(1);
	};
	io::close(pipe.0)!;

	const st = match (exec::wait(&proc)) {
	case let s: exec::status =>
		yield s;
	case =>
		cprint(C_RED, "ERR", "openssl process failed", nc);
		os::exit(1);
	};
	match (exec::exit(&st)) {
	case exec::exited =>
		void;
	case =>
		cprint(C_RED, "ERR", "openssl encryption failed", nc);
		os::exit(1);
	};

	const encrypted = strings::fromutf8(outbuf[..n])!;

	fmt::println("")!;
	cprint(C_GREEN, "OK", "Rooster link generated!", nc);
	fmt::println("")!;
	if (!nc) fmt::print(C_GREEN)!;
	fmt::printfln("  rooster:?xt=AES256:{}", encrypted)!;
	if (!nc) fmt::print(C_RESET)!;
	fmt::println("")!;
	cprint(C_YELLOW, "TIP", "Share the link above. Recipient downloads with:", nc);
	fmt::printfln("  hpo \"rooster:?xt=AES256:{}\" --code <secret>", encrypted)!;
	fmt::println("")!;
};

// Decrypt a rooster link and return the original URL
fn rooster_decrypt(token: str, code: str, nc: bool) str = {
	if (!check_tool("openssl")) {
		cprint(C_RED, "ERR", "openssl not found! Required for Rooster links.", nc);
		os::exit(1);
	};

	const prefix = "rooster:?xt=AES256:";
	const encrypted = strings::sub(token, len(prefix), strings::end);

	const pipecmd = fmt::asprintf(
		"printf '%s' '{}' | openssl enc -aes-256-cbc -a -A -d -salt -pbkdf2 -pass pass:'{}'",
		encrypted, code,
	)!;
	defer free(pipecmd);

	const cmd = match (exec::cmd("sh", "-c", pipecmd)) {
	case let c: exec::command =>
		yield c;
	case =>
		cprint(C_RED, "ERR", "failed to build decryption command", nc);
		os::exit(1);
	};

	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	exec::addfile(&cmd, os::stderr_file, exec::nullfd)!;

	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		cprint(C_RED, "ERR", "failed to start openssl", nc);
		os::exit(1);
	};
	io::close(pipe.1)!;

	static let outbuf: [4096]u8 = [0...];
	const n = match (io::read(pipe.0, outbuf)) {
	case let n: size =>
		yield n;
	case =>
		cprint(C_RED, "ERR", "Wrong code or corrupted Rooster link.", nc);
		fmt::println("  Make sure you have the correct secret code from the sender.")!;
		os::exit(1);
	};
	io::close(pipe.0)!;

	const st = match (exec::wait(&proc)) {
	case let s: exec::status =>
		yield s;
	case =>
		cprint(C_RED, "ERR", "openssl process failed", nc);
		os::exit(1);
	};
	match (exec::exit(&st)) {
	case exec::exited =>
		void;
	case =>
		cprint(C_RED, "ERR", "Wrong code or corrupted Rooster link.", nc);
		fmt::println("  Make sure you have the correct secret code from the sender.")!;
		os::exit(1);
	};

	if (n == 0) {
		cprint(C_RED, "ERR", "Decryption produced empty output - wrong code?", nc);
		os::exit(1);
	};

	return strings::fromutf8(outbuf[..n])!;
};

fn do_http_custom(o: *opts) void = {
	if (!check_tool("curl")) {
		cprint(C_RED, "ERR", "curl not found! Install: sudo apt install curl", o.nocolor);
		os::exit(1);
	};

	const ua = if (len(o.agent) > 0) o.agent else "hpo/1.4 (Hare; Linux; harelang.org)";

	if (!o.quiet) {
		cprint(C_CYAN, "HPO", "Dragon Warrior prepares the download...", o.nocolor);
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		fmt::printfln("  URL:    {}", o.url)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		if (!o.nocolor) fmt::print(C_GREEN)!;
		fmt::printfln("  Output: {}", o.output)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		if (o.resume) {
			cprint(C_YELLOW, "HPO", "Resume mode ON", o.nocolor);
		};
		if (len(o.rate) > 0) {
			if (!o.nocolor) fmt::print(C_MAGENTA)!;
			fmt::printfln("  Rate:   {}/s", o.rate)!;
			if (!o.nocolor) fmt::print(C_RESET)!;
		};
		fmt::println("")!;
		cprint(C_CYAN, "HPO", "Checking file size...", o.nocolor);
	};

	const total = get_content_length(o.url, ua);
	if (!o.quiet && total > 0) {
		if (!o.nocolor) fmt::print(C_MAGENTA)!;
		fmt::printfln("  Size:   {}", format_size(total))!;
		if (!o.nocolor) fmt::print(C_RESET)!;
	};

	if (!o.quiet) {
		fmt::println("")!;
		cprint(C_GREEN, "HPO", "Skadoosh! Download starting...", o.nocolor);
		fmt::println("")!;
	};

	const cmd = match (exec::cmd("curl", "-g", "--silent", "-L",
		"-A", ua, "-o", o.output, o.url)) {
	case let c: exec::command =>
		yield c;
	case exec::nocmd =>
		cprint(C_RED, "ERR", "curl not found", o.nocolor);
		os::exit(1);
	case =>
		cprint(C_RED, "ERR", "failed to build command", o.nocolor);
		os::exit(1);
	};

	const proc = match (exec::start(&cmd)) {
	case let p: exec::process =>
		yield p;
	case =>
		cprint(C_RED, "ERR", "failed to start curl", o.nocolor);
		os::exit(1);
	};

	const start_time = time::now(time::clock::MONOTONIC);
	let finished = false;
	for (!finished) {
		match (exec::peek(&proc)) {
		case let s: exec::status =>
			if (!o.quiet) {
				const now = time::now(time::clock::MONOTONIC);
				const dur = time::diff(start_time, now);
				const elapsed_secs = (dur / time::SECOND): size;
				const final_size = get_file_size(o.output);
				const actual_total = if (total > 0) total else final_size;
				draw_progress(actual_total, actual_total, elapsed_secs, o.nocolor);
				fmt::println("")!;
			};
			match (exec::exit(&s)) {
			case let e: exec::exited =>
				if (e != 0) {
					fmt::println("")!;
					cprint(C_RED, "FAIL", "Download failed!", o.nocolor);
					os::exit(1);
				};
			case =>
				fmt::println("")!;
				cprint(C_RED, "ERR", "curl exited abnormally", o.nocolor);
				os::exit(1);
			};
			finished = true;
		case void =>
			if (!o.quiet) {
				const now = time::now(time::clock::MONOTONIC);
				const dur = time::diff(start_time, now);
				const elapsed_secs = (dur / time::SECOND): size;
				const current = get_file_size(o.output);
				draw_progress(current, total, elapsed_secs, o.nocolor);
			};
			time::sleep(250 * time::MILLISECOND);
		case =>
			finished = true;
		};
	};

	if (!o.quiet) {
		fmt::println("")!;
		cprint(C_GREEN, "OK", "Download complete! The Dragon Warrior delivers!", o.nocolor);
		fmt::printfln("  Saved to: {}", o.output)!;
		fmt::printfln("  Size:     {}", format_size(get_file_size(o.output)))!;
	};
};

fn do_magnet(o: *opts) void = {
	if (!check_tool("aria2c")) {
		cprint(C_RED, "ERR", "aria2c not found! Install: sudo apt install aria2", o.nocolor);
		os::exit(1);
	};
	if (!o.quiet) {
		cprint(C_BLUE, "HPO", "Magnet link detected! Using aria2c backend...", o.nocolor);
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		const preview = if (len(o.url) < 60) len(o.url) else 60z;
		fmt::printfln("  Magnet: {}...", strings::sub(o.url, 0, preview))!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		if (!o.nocolor) fmt::print(C_GREEN)!;
		fmt::printfln("  Dir:    {}", o.output)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		if (len(o.rate) > 0) {
			if (!o.nocolor) fmt::print(C_MAGENTA)!;
			fmt::printfln("  Rate:   {}/s", o.rate)!;
			if (!o.nocolor) fmt::print(C_RESET)!;
		};
		fmt::println("")!;
		cprint(C_GREEN, "HPO", "There is no charge for awesomeness... or attractiveness. Connecting to swarm...", o.nocolor);
		fmt::println("")!;
	};
	let args: []str = alloc([], 16)!;
	defer free(args);
	append(args, "aria2c")!;
	append(args, "--summary-interval=1")!;
	const seedtime = if (len(o.seed) > 0) o.seed else "0";
	append(args, "--seed-time")!;
	append(args, seedtime)!;
	append(args, "--dir")!;
	append(args, o.output)!;
	if (len(o.rate) > 0) {
		append(args, "--max-download-limit")!;
		append(args, o.rate)!;
	};
	append(args, "--enable-dht=true")!;
	append(args, "--bt-enable-lpd=true")!;
	append(args, "--allow-overwrite=true")!;
	append(args, o.url)!;
	if (run_cmd(args, o.nocolor)) {
		if (!o.quiet) {
			const quote = tiger_quote();
			static let qbuf: [256]u8 = [0...];
			const msg = fmt::bsprintf(qbuf, "Torrent complete! \"{}\" - Tigress", quote)!;
			cprint(C_GREEN, "OK", msg, o.nocolor);
			fmt::printfln("  Saved to: {}", o.output)!;
		};
	} else {
		os::exit(1);
	};
};

fn do_gdrive(o: *opts) void = {
	const file_id = gdrive_file_id(o.url);
	if (len(file_id) == 0) {
		cprint(C_RED, "ERR", "Could not extract Google Drive file ID from URL", o.nocolor);
		os::exit(1);
	};

	static let urlbuf: [512]u8 = [0...];
	const gurl = fmt::bsprintf(urlbuf, "https://drive.google.com/uc?id={}", file_id)!;

	const home = match (os::getenv("HOME")) {
	case let s: str =>
		yield s;
	case void =>
		yield "/tmp";
	};
	static let gdown_path: [512]u8 = [0...];
	let gdown_bin = "gdown";
	if (!check_tool_help(gdown_bin)) {
		gdown_bin = fmt::bsprintf(gdown_path, "{}/.local/bin/gdown", home)!;
		if (!check_tool_help(gdown_bin)) {
			cprint(C_RED, "ERR", "gdown not found! Install: pip install gdown", o.nocolor);
			os::exit(1);
		};
	};

	if (!o.quiet) {
		cprint(C_BLUE, "HPO", "Google Drive link detected! Using gdown backend...", o.nocolor);
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		fmt::printfln("  File ID: {}", file_id)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		if (!o.nocolor) fmt::print(C_GREEN)!;
		fmt::printfln("  Output:  {}", o.output)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		fmt::println("")!;
		cprint(C_GREEN, "HPO", "Skadoosh! Fetching from Google Drive...", o.nocolor);
		fmt::println("")!;
	};

	let args: []str = alloc([], 8)!;
	defer free(args);
	append(args, gdown_bin)!;
	append(args, gurl)!;
	append(args, "-O")!;
	append(args, o.output)!;
	if (o.quiet) {
		append(args, "-q")!;
	};

	if (run_cmd(args, o.nocolor)) {
		if (!o.quiet) {
			cprint(C_GREEN, "OK", "Download complete! The Dragon Warrior delivers!", o.nocolor);
			fmt::printfln("  Saved to: {}", o.output)!;
		};
	} else {
		if (!o.quiet) {
			cprint(C_RED, "FAIL", "Google Drive download failed!", o.nocolor);
		};
		os::exit(1);
	};
};

fn do_download(o: *opts) void = {
	// Lock mode: encrypt URL into rooster link
	if (len(o.lock) > 0) {
		if (len(o.code) == 0) {
			cprint(C_RED, "ERR", "Rooster link requires --code <secret>", o.nocolor);
			fmt::println("  Usage: hpo --lock <url> --code <secret>")!;
			os::exit(1);
		};
		rooster_encrypt(o.lock, o.code, o.nocolor);
		return;
	};

	// Rooster link: decrypt and download
	if (is_rooster(o.url)) {
		if (len(o.code) == 0) {
			cprint(C_RED, "ERR", "This is a Rooster link - a secret code is required!", o.nocolor);
			fmt::println("  Ask the sender for the code and use:")!;
			fmt::println("  hpo \"rooster:...\" --code <secret>")!;
			os::exit(1);
		};

		if (!o.quiet) {
			if (!o.nocolor) fmt::print(C_CYAN)!;
			fmt::println("
  _    _  _____   ___  
 | |  | ||  __ \\ / _ \\ 
 | |__| || |__) | | | |
 |  __  ||  ___/| | | |
 | |  | || |    | |_| |
 |_|  |_||_|     \\___/ 

  hpo - The Hare Download Manager
  Rooster Link Detected!
")!;
			if (!o.nocolor) fmt::print(C_RESET)!;
			fmt::printfln("  Version {} | https://harelang.org\n", VERSION)!;
			cprint(C_MAGENTA, "HPO", "Decrypting Rooster link...", o.nocolor);
		};

		const decrypted = rooster_decrypt(o.url, o.code, o.nocolor);

		if (!o.quiet) {
			cprint(C_GREEN, "OK", "Rooster link decrypted!", o.nocolor);
			if (!o.nocolor) fmt::print(C_YELLOW)!;
			fmt::printfln("  Resolved: {}", decrypted)!;
			if (!o.nocolor) fmt::print(C_RESET)!;
			fmt::println("")!;
		};

		o.url = decrypted;
		o.output = "";
		if (len(o.output) == 0) {
			o.output = default_output(o.url);
		};

		if (is_magnet(o.url)) {
			do_magnet(o);
		} else if (is_gdrive(o.url)) {
			do_gdrive(o);
		} else {
			do_http_custom(o);
		};
		return;
	};

	// Normal download
	if (!o.quiet) {
		if (!o.nocolor) fmt::print(C_CYAN)!;
		fmt::println("
  _    _  _____   ___  
 | |  | ||  __ \\ / _ \\ 
 | |__| || |__) | | | |
 |  __  ||  ___/| | | |
 | |  | || |    | |_| |
 |_|  |_||_|     \\___/ 

  hpo - The Hare Download Manager
  Skadoosh! File incoming!
")!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		fmt::printfln("  Version {} | https://harelang.org\n", VERSION)!;
	};
	if (is_magnet(o.url)) {
		do_magnet(o);
	} else if (is_gdrive(o.url)) {
		do_gdrive(o);
	} else {
		do_http_custom(o);
	};
};

fn print_help() void = {
	fmt::println("hpo - The Hare Download Manager v1.4.0\n")!;
	fmt::println("USAGE:")!;
	fmt::println("  hpo <url|magnet|rooster> [options]\n")!;
	fmt::println("OPTIONS:")!;
	fmt::println("  -o <path>     Output file (HTTP/GDrive) or directory (magnet)")!;
	fmt::println("                Default: ~/Downloads/")!;
	fmt::println("  -r            Resume interrupted HTTP download")!;
	fmt::println("  -R <speed>    Rate limit (e.g. 500k, 2m, 1g)")!;
	fmt::println("  -u <agent>    Custom User-Agent (HTTP only)")!;
	fmt::println("  -s <mins>     Seed time after torrent (default: 0)")!;
	fmt::println("  --lock <url>  Create a Rooster link (encrypted URL)")!;
	fmt::println("  --code <key>  Secret code for Rooster links")!;
	fmt::println("  -v            Verbose output")!;
	fmt::println("  -q            Quiet mode")!;
	fmt::println("  --no-color    Disable colors")!;
	fmt::println("  -h            This help\n")!;
	fmt::println("EXAMPLES:")!;
	fmt::println("  hpo https://example.com/file.zip")!;
	fmt::println("  hpo https://example.com/video.mp4 -R 2m")!;
	fmt::println("  hpo https://drive.google.com/file/d/FILE_ID/view")!;
	fmt::println("  hpo --lock https://secret.com/file.zip --code mykey")!;
	fmt::println("  hpo \"rooster:?xt=AES256:...\" --code mykey")!;
	fmt::println("  hpo \"magnet:?xt=urn:btih:abc123...\"\n")!;
	fmt::println("BACKENDS:")!;
	fmt::println("  HTTP/HTTPS/FTP  -> curl (dragon progress bar)")!;
	fmt::println("  Google Drive    -> gdown")!;
	fmt::println("  magnet:         -> aria2c")!;
	fmt::println("  rooster:        -> openssl (AES-256-CBC)\n")!;
};

export fn main() void = {
	const args = os::args;
	if (len(args) < 2) {
		print_help();
		os::exit(1);
	};
	let o = opts {
		url     = "",
		output  = "",
		resume  = false,
		rate    = "",
		agent   = "",
		seed    = "",
		code    = "",
		lock    = "",
		verbose = false,
		quiet   = false,
		nocolor = false,
	};
	let i = 1z;
	for (i < len(args); i += 1) {
		const a = args[i];
		if (a == "-h" || a == "--help") {
			print_help();
			os::exit(0);
		} else if (a == "--version") {
			fmt::printfln("hpo {}", VERSION)!;
			os::exit(0);
		} else if (a == "-r" || a == "--resume") {
			o.resume = true;
		} else if (a == "-v" || a == "--verbose") {
			o.verbose = true;
		} else if (a == "-q" || a == "--quiet") {
			o.quiet = true;
		} else if (a == "--no-color") {
			o.nocolor = true;
		} else if (a == "--lock") {
			i += 1;
			if (i >= len(args)) {
				fmt::errorfln("Error: --lock requires a URL")!;
				os::exit(1);
			};
			o.lock = args[i];
		} else if (a == "--code") {
			i += 1;
			if (i >= len(args)) {
				fmt::errorfln("Error: --code requires a secret")!;
				os::exit(1);
			};
			o.code = args[i];
		} else if (a == "-o" || a == "--output") {
			i += 1;
			if (i >= len(args)) {
				fmt::errorfln("Error: -o requires a path")!;
				os::exit(1);
			};
			o.output = args[i];
		} else if (a == "-R" || a == "--rate") {
			i += 1;
			if (i >= len(args)) {
				fmt::errorfln("Error: -R requires a speed")!;
				os::exit(1);
			};
			o.rate = args[i];
		} else if (a == "-s" || a == "--seed") {
			i += 1;
			if (i >= len(args)) {
				fmt::errorfln("Error: -s requires minutes")!;
				os::exit(1);
			};
			o.seed = args[i];
		} else if (a == "-u" || a == "--user-agent") {
			i += 1;
			if (i >= len(args)) {
				fmt::errorfln("Error: -u requires a string")!;
				os::exit(1);
			};
			o.agent = args[i];
		} else if (strings::hasprefix(a, "-")) {
			fmt::errorfln("Error: unknown option: {}", a)!;
			os::exit(1);
		} else {
			o.url = a;
		};
	};
	if (len(o.url) == 0 && len(o.lock) == 0) {
		fmt::errorfln("Error: no URL provided. Run hpo -h for help.")!;
		os::exit(1);
	};
	if (len(o.output) == 0 && len(o.url) > 0) {
		o.output = default_output(o.url);
	};
	do_download(&o);
};
