use fmt;
use io;
use os;
use os::exec;
use strings;
use bufio;
use time;
use fs;

def VERSION = "3.3.4";

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
	oogway: bool,
	oogway_sec: uint,
	url:     str,
	output:  str,
	resume:  bool,
	rate:    str,
	agent:   str,
	seed:    str,
	code:    str,
	lock:    str,
        token:   str,
        cookie:  str,
	epic:    bool,
	epic_cmd: str,
	steam:    bool,
	steam_cmd: str,
	zhen_setup: bool,
	zhen_proton: bool,
        suno:    bool,
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

fn is_mega(url: str) bool = {
	return strings::hasprefix(url, "https://mega.nz/");
};

fn is_rooster(url: str) bool = {
	return strings::hasprefix(url, "rooster:?xt=AES256:");
};

fn is_suno(url: str) bool = {
        return strings::hasprefix(url, "https://suno.com/song/");
};

fn is_itch(url: str) bool = {
        return strings::hasprefix(url, "itch:");
};

fn is_gog(url: str) bool = {
        return strings::hasprefix(url, "gog:");
};

fn is_suno_cdn(url: str) bool = {
        return strings::hasprefix(url, "https://cdn1.suno.ai/");
};

fn suno_cdn_to_song(url: str) str = {
        const prefix = "https://cdn1.suno.ai/";
        const rest = strings::sub(url, len(prefix), strings::end);
        const dot = match (strings::index(rest, '.')) {
        case let i: size =>
                yield i;
        case void =>
                yield len(rest);
        };
        const uuid = strings::sub(rest, 0, dot);
        static let buf: [512]u8 = [0...];
        return fmt::bsprintf(buf, "https://suno.com/song/{}", uuid)!;
};

fn suno_to_cdn(url: str) str = {
        const prefix = "https://suno.com/song/";
        const uuid = strings::sub(url, len(prefix), strings::end);
        static let buf: [512]u8 = [0...];
        return fmt::bsprintf(buf, "https://cdn1.suno.ai/{}.mp3", uuid)!;
};

fn suno_get_title(url: str) str = {
        const cmd = match (exec::cmd("curl", "-g", "-sL", "--max-time", "5", url)) {
        case let c: exec::command =>
                yield c;
        case =>
                return "";
        };
        const pipe = exec::pipe();
        exec::addfile(&cmd, os::stdout_file, pipe.1)!;
        exec::addfile(&cmd, os::stderr_file, exec::nullfd)!;
        const proc = match (exec::start(&cmd)) {
        case let p: exec::process =>
                yield p;
        case =>
                io::close(pipe.0)!;
                io::close(pipe.1)!;
                return "";
        };
        io::close(pipe.1)!;
        static let sbuf: [65536]u8 = [0...];
        let total = 0z;
        for (true) {
                const n = match (io::read(pipe.0, sbuf[total..])) {
                case let n: size =>
                        yield n;
                case io::EOF =>
                        break;
                case =>
                        break;
                };
                total += n;
                if (total >= len(sbuf) - 1) break;
        };
        io::close(pipe.0)!;
        exec::wait(&proc)!;
        const html = strings::fromutf8(sbuf[..total])!;
        const tag = "<title>";
        const idx = match (strings::index(html, tag)) {
        case let i: size =>
                yield i;
        case void =>
                return "";
        };
        const rest = strings::sub(html, idx + len(tag), strings::end);
        const end = match (strings::index(rest, "</title>")) {
        case let i: size =>
                yield i;
        case void =>
                return "";
        };
        const raw = strings::sub(rest, 0, end);
        const d1 = strings::replace(raw, "&#x27;", "'")!;
        const d2 = strings::replace(d1, "&amp;", "&")!;
        const d3 = strings::replace(d2, "&quot;", "\"")!;
        const d4 = strings::replace(d3, "&#39;", "'")!;
        return d4;
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
	if (is_mega(url)) {
		static let megabuf: [512]u8 = [0...];
		return fmt::bsprintf(megabuf, "{}/Downloads", home)!;
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

fn get_content_length(url: str, ua: str, token: str, cookie: str) size = {
	const auth_hdr = if (len(token) > 0) fmt::asprintf("Authorization: token {}", token)! else "";
        const cmd = match (if (len(token) > 0) exec::cmd("curl", "-g", "-sI", "-L", "--max-time", "5", "-A", ua, "-H", auth_hdr, "-b", cookie, url) else if (len(cookie) > 0) exec::cmd("curl", "-g", "-sI", "-L", "--max-time", "5", "-A", ua, "-b", cookie, url) else exec::cmd("curl", "-g", "-sI", "-L", "--max-time", "5", "-A", ua, url)) {
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

	const total = get_content_length(o.url, ua, o.token, o.cookie);
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

	const auth = if (len(o.token) > 0) fmt::asprintf("Authorization: token {}", o.token)! else "";
        const cmd = match (if (len(o.token) > 0) exec::cmd("curl", "-g", "--silent", "-L", "-H", auth, "-b", o.cookie, "-A", ua, "-o", o.output, o.url) else if (len(o.cookie) > 0) exec::cmd("curl", "-g", "--silent", "-L", "-b", o.cookie, "-A", ua, "-o", o.output, o.url) else exec::cmd("curl", "-g", "--silent", "-L",
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
	if (o.suno && get_file_size(o.output) < 1024) {
		cprint(C_RED, "ERR", "Song not available - private or deleted on Suno", o.nocolor);
		os::remove(o.output)!;
		return;
	};
	if (o.suno) {
		if (!o.quiet) cprint(C_CYAN, "HPO", "Converting to MP3...", o.nocolor);
		static let mp3buf: [512]u8 = [0...];
		const mp3out = fmt::bsprintf(mp3buf, "{}", o.output)!;
		const m4a = o.output;
		static let mp3path: [512]u8 = [0...];
		const mp3file = strings::sub(m4a, 0, len(m4a) - 4);
		const mp3 = strings::replace(m4a, ".m4a", ".mp3")!;
		const args: []str = ["ffmpeg", "-y", "-i", m4a, "-q:a", "0", mp3];
		if (run_cmd(args, o.nocolor)) {
			os::remove(m4a)!;
			if (!o.quiet) {
				cprint(C_GREEN, "OK", "Converted to MP3!", o.nocolor);
				fmt::printfln("  MP3: {}", mp3)!;
			};
		} else {
			cprint(C_YELLOW, "WARN", "ffmpeg conversion failed, keeping .m4a", o.nocolor);
		};
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

fn do_mega(o: *opts) void = {
	if (!check_tool("megadl")) {
		cprint(C_RED, "ERR", "megadl not found! Install: sudo apt install megatools", o.nocolor);
		os::exit(1);
	};
	if (!o.quiet) {
		cprint(C_BLUE, "HPO", "Mega link detected! Using megadl backend...", o.nocolor);
		fmt::println("")!;
		cprint(C_GREEN, "HPO", "Skadoosh! Fetching from Mega...", o.nocolor);
		fmt::println("")!;
	};
	let args: []str = alloc([], 8)!;
	defer free(args);
	append(args, "megadl")!;
	append(args, "--path")!;
	append(args, o.output)!;
	append(args, o.url)!;
	if (run_cmd(args, o.nocolor)) {
		if (!o.quiet) {
			cprint(C_GREEN, "OK", "Download complete! The Dragon Warrior delivers!", o.nocolor);
			fmt::printfln("  Saved to: {}", o.output)!;
		};
	} else {
		if (!o.quiet) {
			cprint(C_RED, "FAIL", "Mega download failed!", o.nocolor);
		};
		os::exit(1);
	};
};

fn do_zhen_setup(o: *opts) void = {
	if (!check_tool("curl")) {
		cprint(C_RED, "ERR", "curl not found! Install: sudo apt install curl", o.nocolor);
		os::exit(1);
	};
	if (!check_tool("tar")) {
		cprint(C_RED, "ERR", "tar not found!", o.nocolor);
		os::exit(1);
	};
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let zhen_dir_buf: [512]u8 = [0...];
	const zhen_dir = fmt::bsprintf(zhen_dir_buf, "{}/.local/share/hpo/zhen", home)!;
	static let zhen_run_buf: [512]u8 = [0...];
	const zhen_run = fmt::bsprintf(zhen_run_buf, "{}/umu-run", zhen_dir)!;
	static let zhen_py_buf: [512]u8 = [0...];
	const zhen_py = fmt::bsprintf(zhen_py_buf, "{}/umu_run.py", zhen_dir)!;
	static let tar_buf: [512]u8 = [0...];
	const tar_path = fmt::bsprintf(tar_buf, "{}/umu.tar", zhen_dir)!;

	if (!o.quiet) {
		cprint(C_BLUE, "ZHEN", "Awakening the Dragon Warrior engine...", o.nocolor);
		fmt::printfln("  Target: {}", zhen_dir)!;
		fmt::println("")!;
	};

	// Lav mapper
	static let mkdir_buf: [512]u8 = [0...];
	const share_dir = fmt::bsprintf(mkdir_buf, "{}/.local/share/hpo", home)!;
	os::mkdir(share_dir, 0o755): void;
	os::mkdir(zhen_dir, 0o755): void;

	// Download umu-launcher zipapp
	if (!o.quiet) cprint(C_YELLOW, "ZHEN", "Downloading umu-launcher 1.4.0...", o.nocolor);
	const url = "https://github.com/Open-Wine-Components/umu-launcher/releases/download/1.4.0/umu-launcher-1.4.0-zipapp.tar";
	let dl_args: []str = alloc([], 6)!;
	defer free(dl_args);
	append(dl_args, "curl")!;
	append(dl_args, "-L")!;
	append(dl_args, "-o")!;
	append(dl_args, tar_path)!;
	append(dl_args, url)!;
	if (!run_cmd(dl_args, o.nocolor)) {
		cprint(C_RED, "FAIL", "Download failed!", o.nocolor);
		os::exit(1);
	};

	// Pak ud
	if (!o.quiet) cprint(C_YELLOW, "ZHEN", "Extracting...", o.nocolor);
	let tar_args: []str = alloc([], 6)!;
	defer free(tar_args);
	append(tar_args, "tar")!;
	append(tar_args, "-xf")!;
	append(tar_args, tar_path)!;
	append(tar_args, "-C")!;
	append(tar_args, zhen_dir)!;
	append(tar_args, "--strip-components=1")!;
	if (!run_cmd(tar_args, o.nocolor)) {
		cprint(C_RED, "FAIL", "Extract failed!", o.nocolor);
		os::exit(1);
	};

	// chmod +x
	let chmod_args: []str = alloc([], 4)!;
	defer free(chmod_args);
	append(chmod_args, "chmod")!;
	append(chmod_args, "+x")!;
	append(chmod_args, zhen_run)!;
	let _ = run_cmd(chmod_args, o.nocolor);

	// Verificer
	if (os::exists(zhen_run)) {
		if (!o.quiet) {
			fmt::println("")!;
			cprint(C_GREEN, "ZHEN", "Engine ready! The Dragon Warrior has arrived.", o.nocolor);
			fmt::printfln("  Path: {}", zhen_run)!;
		};
	} else {
		cprint(C_RED, "FAIL", "umu-run not found after extract!", o.nocolor);
		os::exit(1);
	};

	// Optional: download GE-Proton if --proton flag was given
	if (o.zhen_proton) {
		static let proton_dir_buf: [512]u8 = [0...];
		const proton_dir = fmt::bsprintf(proton_dir_buf, "{}/proton", zhen_dir)!;
		static let proton_target_buf: [512]u8 = [0...];
		const proton_target = fmt::bsprintf(proton_target_buf, "{}/GE-Proton10-34", proton_dir)!;

		if (os::exists(proton_target)) {
			if (!o.quiet) cprint(C_YELLOW, "ZHEN", "GE-Proton10-34 already installed, skipping.", o.nocolor);
		} else {
			if (!o.quiet) {
				fmt::println("")!;
				cprint(C_BLUE, "ZHEN", "Downloading GE-Proton10-34 (~700MB, patience grasshopper)...", o.nocolor);
			};
			os::mkdir(proton_dir, 0o755): void;
			static let proton_tar_buf: [512]u8 = [0...];
			const proton_tar = fmt::bsprintf(proton_tar_buf, "{}/proton.tar.gz", proton_dir)!;
			const proton_url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz";

			let pdl_args: []str = alloc([], 6)!;
			defer free(pdl_args);
			append(pdl_args, "curl")!;
			append(pdl_args, "-L")!;
			append(pdl_args, "-o")!;
			append(pdl_args, proton_tar)!;
			append(pdl_args, proton_url)!;
			if (!run_cmd(pdl_args, o.nocolor)) {
				cprint(C_RED, "FAIL", "Proton download failed!", o.nocolor);
				os::exit(1);
			};

			if (!o.quiet) cprint(C_YELLOW, "ZHEN", "Extracting Proton (this takes a minute)...", o.nocolor);
			let pex_args: []str = alloc([], 6)!;
			defer free(pex_args);
			append(pex_args, "tar")!;
			append(pex_args, "-xzf")!;
			append(pex_args, proton_tar)!;
			append(pex_args, "-C")!;
			append(pex_args, proton_dir)!;
			if (!run_cmd(pex_args, o.nocolor)) {
				cprint(C_RED, "FAIL", "Proton extract failed!", o.nocolor);
				os::exit(1);
			};

			if (os::exists(proton_target)) {
				if (!o.quiet) {
					cprint(C_GREEN, "ZHEN", "GE-Proton10-34 installed! Full independence achieved.", o.nocolor);
					fmt::printfln("  Path: {}", proton_target)!;
				};
			} else {
				cprint(C_RED, "FAIL", "Proton not found after extract!", o.nocolor);
				os::exit(1);
			};
		};
	};
};

fn is_wsl() bool = {
	const f = match (os::open("/proc/version")) {
	case let file: io::file => yield file;
	case => return false;
	};
	defer io::close(f)!;
	static let buf: [512]u8 = [0...];
	const n = match (io::read(f, buf)) {
	case let nn: size => yield nn;
	case => return false;
	};
	const s = strings::fromutf8(buf[..n])!;
	return strings::contains(s, "Microsoft") || strings::contains(s, "microsoft") || strings::contains(s, "WSL");
};

fn do_steam(o: *opts, target: str) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};

	// Find Steam apps mappe - prøv Flatpak først, så native
	static let flat_buf: [512]u8 = [0...];
	const flat_apps = fmt::bsprintf(flat_buf, "{}/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps", home)!;
	static let nat_buf: [512]u8 = [0...];
	const nat_apps = fmt::bsprintf(nat_buf, "{}/.steam/steam/steamapps", home)!;
	const apps_dir = if (os::exists(flat_apps)) flat_apps else nat_apps;

	// Hvis kommandoen er "list" - vis installerede spil
	if (o.steam_cmd == "list") {
		if (!o.quiet) {
			cprint(C_BLUE, "STEAM", "Po's library of Steam games:", o.nocolor);
			fmt::println("")!;
		};
		let ls_args: []str = alloc([], 4)!;
		defer free(ls_args);
		append(ls_args, "sh")!;
		append(ls_args, "-c")!;
		static let cmd_buf: [1024]u8 = [0...];
		const grep_cmd = fmt::bsprintf(cmd_buf, "awk '/appid|name/' {}/appmanifest_*.acf 2>/dev/null | paste - -", apps_dir)!;
		append(ls_args, grep_cmd)!;
		let _ = run_cmd(ls_args, o.nocolor);
		return;
	};

	// Smart kort syntax: hvis steam_cmd ikke er list/install, så er det selve target'et!
	// Eksempel: "hpo --steam po" => steam_cmd="po", target="" => vi flytter po til target
	if (o.steam_cmd != "list" && o.steam_cmd != "install" && o.steam_cmd != "launch" && len(target) == 0) {
		target = o.steam_cmd;
		o.steam_cmd = "launch";
	};

	// Hvis kommandoen er "launch" eller "install" - kør URI
	if (len(target) == 0) {
		cprint(C_RED, "ERR", "Steam command requires app-ID or alias!", o.nocolor);
		os::exit(1);
	};

	// Læs alias-fil
	static let alias_buf: [512]u8 = [0...];
	const alias_path = fmt::bsprintf(alias_buf, "{}/.config/hpo/steam_aliases.txt", home)!;
	let appid = target;
	match (os::open(alias_path)) {
	case let f: io::file =>
		static let rbuf: [4096]u8 = [0...];
		const n = match (io::read(f, rbuf)) {
		case let n: size => yield n;
		case => yield 0z;
		};
		io::close(f)!;
		const contents = strings::fromutf8(rbuf[..n])!;
		const lines = match (strings::split(contents, "\n")) {
		case let s: []str => yield s;
		case => yield []: []str;
		};
		defer free(lines);
		for (let i = 0z; i < len(lines); i += 1) {
			const line = strings::trim(lines[i]);
			if (len(line) == 0) continue;
			const parts = match (strings::split(line, "=")) {
			case let s: []str => yield s;
			case => yield []: []str;
			};
			defer free(parts);
			if (len(parts) >= 2 && strings::trim(parts[0]) == target) {
				appid = strings::trim(parts[1]);
				break;
			};
		};
	case => void;
	};

	static let uri_buf: [512]u8 = [0...];
	const action = if (o.steam_cmd == "install") "install" else "rungameid";
	const uri = fmt::bsprintf(uri_buf, "steam://{}/{}", action, appid)!;

	// WSL detection: hvis vi er på WSL, bridge til Windows Steam i stedet
	const on_wsl = is_wsl();

	// Auto-link Zhen's GE-Proton til Steam (kun på native Linux, ikke WSL)
	static let zhen_src_buf: [512]u8 = [0...];
	const zhen_proton_src = fmt::bsprintf(zhen_src_buf, "{}/.local/share/hpo/zhen/proton/GE-Proton10-34", home)!;
	static let steam_compat_buf: [512]u8 = [0...];
	const steam_compat_dir = fmt::bsprintf(steam_compat_buf, "{}/.var/app/com.valvesoftware.Steam/.local/share/Steam/compatibilitytools.d", home)!;
	static let steam_target_buf: [512]u8 = [0...];
	const steam_target = fmt::bsprintf(steam_target_buf, "{}/GE-Proton10-34", steam_compat_dir)!;
	if (!on_wsl && os::exists(zhen_proton_src) && !os::exists(steam_target)) {
		if (!o.quiet) cprint(C_YELLOW, "ZHEN", "Linking Zhen's GE-Proton to Steam...", o.nocolor);
		os::mkdir(steam_compat_dir, 0o755): void;
		let ln_args: []str = alloc([], 5)!;
		defer free(ln_args);
		append(ln_args, "ln")!;
		append(ln_args, "-sf")!;
		append(ln_args, zhen_proton_src)!;
		append(ln_args, steam_target)!;
		let _ = run_cmd(ln_args, o.nocolor);
	};

	if (!o.quiet) {
		cprint(C_BLUE, "HPO", "Steam game detected!", o.nocolor);
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		fmt::printfln("  Action: {}", o.steam_cmd)!;
		fmt::printfln("  AppID:  {}", appid)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		fmt::println("")!;
		if (on_wsl) {
			cprint(C_YELLOW, "ZHEN", "Bridging to Windows Steam via WSL...", o.nocolor);
			cprint(C_GREEN, "STEAM", "Skadoosh! Po races to Steam through the Zhen bridge!", o.nocolor);
		} else {
			cprint(C_YELLOW, "ZHEN", "Dragon Warrior engine activated!", o.nocolor);
			cprint(C_GREEN, "STEAM", "Skadoosh! Po races to Steam with Zhen's engine!", o.nocolor);
		};
		fmt::println("")!;
	};

	// Bestem launch-metode: WSL → cmd.exe, native Linux → steam/flatpak
	let steam_args: []str = alloc([], 6)!;
	defer free(steam_args);
	if (on_wsl) {
		append(steam_args, "cmd.exe")!;
		append(steam_args, "/c")!;
		append(steam_args, "start")!;
		append(steam_args, "")!;
		append(steam_args, uri)!;
	} else if (check_tool("steam")) {
		append(steam_args, "steam")!;
		append(steam_args, uri)!;
	} else {
		append(steam_args, "flatpak")!;
		append(steam_args, "run")!;
		append(steam_args, "com.valvesoftware.Steam")!;
		append(steam_args, uri)!;
	};

	if (run_cmd(steam_args, o.nocolor)) {
		if (!o.quiet) cprint(C_GREEN, "OK", "Steam action complete! Vroom vroom!", o.nocolor);
	} else {
		if (!o.quiet) cprint(C_RED, "FAIL", "Steam action failed!", o.nocolor);
		os::exit(1);
	};
};

fn do_epic(o: *opts, gamename_in: str) void = {
	// Læs Epic alias-fil og resolve gamename hvis det er et alias
	const home_a = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let ealias_buf: [512]u8 = [0...];
	const ealias_path = fmt::bsprintf(ealias_buf, "{}/.config/hpo/epic_aliases.txt", home_a)!;
	let gamename = gamename_in;
	match (os::open(ealias_path)) {
	case let f: io::file =>
		static let erbuf: [4096]u8 = [0...];
		const en = match (io::read(f, erbuf)) {
		case let n: size => yield n;
		case => yield 0z;
		};
		io::close(f)!;
		const econtents = strings::fromutf8(erbuf[..en])!;
		const elines = match (strings::split(econtents, "\n")) {
		case let s: []str => yield s;
		case => yield []: []str;
		};
		defer free(elines);
		for (let i = 0z; i < len(elines); i += 1) {
			const line = strings::trim(elines[i]);
			if (len(line) == 0) continue;
			const parts = match (strings::split(line, "=")) {
			case let s: []str => yield s;
			case => yield []: []str;
			};
			defer free(parts);
			if (len(parts) >= 2 && strings::trim(parts[0]) == gamename_in) {
				gamename = strings::trim(parts[1]);
				break;
			};
		};
	case => void;
	};

	// WSL bridge: brug Epic Games Launcher URI handler i Windows
	if (is_wsl()) {
		if (o.epic_cmd == "list") {
			cprint(C_RED, "ERR", "list action requires legendary (not available via WSL bridge)", o.nocolor);
			os::exit(1);
		};
		if (!o.quiet) {
			cprint(C_BLUE, "HPO", "Epic Games detected! Bridging to Windows...", o.nocolor);
			if (!o.nocolor) fmt::print(C_YELLOW)!;
			fmt::printfln("  Action: {}", o.epic_cmd)!;
			fmt::printfln("  Game:   {}", gamename)!;
			if (!o.nocolor) fmt::print(C_RESET)!;
			fmt::println("")!;
			cprint(C_YELLOW, "ZHEN", "Bridging to Windows Epic Launcher via WSL...", o.nocolor);
			cprint(C_GREEN, "EPIC", "Skadoosh! Po races to Epic through the Zhen bridge!", o.nocolor);
			fmt::println("")!;
		};
		static let epic_uri_buf: [512]u8 = [0...];
		const epic_uri = fmt::bsprintf(epic_uri_buf, "com.epicgames.launcher://apps/{}?action={}&locale=en-US", gamename, o.epic_cmd)!;
		let epic_args: []str = alloc([], 5)!;
		defer free(epic_args);
		append(epic_args, "cmd.exe")!;
		append(epic_args, "/c")!;
		append(epic_args, "start")!;
		append(epic_args, "")!;
		append(epic_args, epic_uri)!;
		if (run_cmd(epic_args, o.nocolor)) {
			if (!o.quiet) cprint(C_GREEN, "OK", "Epic action complete! The Dragon Warrior delivers!", o.nocolor);
		} else {
			if (!o.quiet) cprint(C_RED, "FAIL", "Epic action failed!", o.nocolor);
			os::exit(1);
		};
		return;
	};

	if (!check_tool("legendary")) {
		cprint(C_RED, "ERR", "legendary not found! Install: pipx install legendary-gl", o.nocolor);
		os::exit(1);
	};
	if (!o.quiet) {
		cprint(C_BLUE, "HPO", "Epic Games detected! Using legendary backend...", o.nocolor);
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		fmt::printfln("  Action: {}", o.epic_cmd)!;
		fmt::printfln("  Game:   {}", gamename)!;
		if (!o.nocolor) fmt::print(C_RESET)!;
		fmt::println("")!;
		cprint(C_GREEN, "ZHEN", "Dragon Warrior engine activated! Launching legendary...", o.nocolor);
		fmt::println("")!;
	};
	// Setup umu-launcher env for launch action - per-game prefix
	if (o.epic_cmd == "launch") {
		const home = match (os::getenv("HOME")) {
		case let s: str => yield s;
		case void => yield "/tmp";
		};
		static let base_buf: [512]u8 = [0...];
		const base = fmt::bsprintf(base_buf, "{}/.proton-prefix-epic", home)!;
		os::mkdir(base, 0o755): void;
		static let prefix_buf: [512]u8 = [0...];
		const prefix = fmt::bsprintf(prefix_buf, "{}/{}", base, gamename)!;
		os::mkdir(prefix, 0o755): void;
		static let proton_buf: [512]u8 = [0...];
		const proton_path = fmt::bsprintf(proton_buf, "{}/.local/share/hpo/zhen/proton/GE-Proton10-34", home)!;
		if (!os::exists(proton_path)) {
			cprint(C_RED, "ERR", "Zhen Proton not found! Run: hpo --zhen-setup --proton", o.nocolor);
			os::exit(1);
		};
		static let steam_buf: [512]u8 = [0...];
		const steam_path = fmt::bsprintf(steam_buf, "{}/.local/share/hpo/zhen", home)!;
		os::setenv("WINEPREFIX", prefix)!;
		os::setenv("STEAM_COMPAT_DATA_PATH", prefix)!;
		os::setenv("STEAM_COMPAT_CLIENT_INSTALL_PATH", steam_path)!;
		os::setenv("PROTONPATH", proton_path)!;
		os::setenv("GAMEID", "umu-0")!;
		os::setenv("STORE", "egs")!;
		os::setenv("PROTON_USE_WINED3D", "0")!;
		os::setenv("DXVK_ASYNC", "1")!;
		os::setenv("WINE_FULLSCREEN_FSR", "1")!;
		os::setenv("PROTON_ENABLE_NVAPI", "1")!;
		os::setenv("LANG", "en_US.UTF-8")!;
		os::setenv("LC_ALL", "en_US.UTF-8")!;
		os::setenv("DXVK_NVAPI_ALLOW_OTHER_DRIVERS", "1")!;
		os::setenv("PROTON_HIDE_NVIDIA_GPU", "0")!;
		os::setenv("WINEESYNC", "1")!;
		os::setenv("WINEFSYNC", "1")!;
		if (!o.quiet) {
			fmt::printfln("  Prefix: {}", prefix)!;
			fmt::printfln("  Proton: GE-Proton10-34")!;
			fmt::println("")!;
		};
	};
	let args: []str = alloc([], 8)!;
	defer free(args);
	if (o.epic_cmd == "install") {
		// Python 3.14 multiprocessing forkserver workaround
		os::setenv("PYTHON_MULTIPROCESSING_START_METHOD", "spawn")!;
	};
	append(args, "legendary")!;
	append(args, o.epic_cmd)!;
	append(args, gamename)!;
	if (o.epic_cmd == "install") {
		append(args, "--max-workers")!;
		append(args, "1")!;
	};
	if (o.epic_cmd == "launch") {
		const home2 = match (os::getenv("HOME")) {
		case let s: str => yield s;
		case void => yield "/tmp";
		};
		static let zhen_buf: [512]u8 = [0...];
		const zhen_path = fmt::bsprintf(zhen_buf, "{}/.local/share/hpo/zhen/umu-run", home2)!;
		if (!os::exists(zhen_path)) {
			cprint(C_RED, "ERR", "Zhen engine not found! Run: hpo --zhen-setup --proton", o.nocolor);
			os::exit(1);
		};
		append(args, "--no-wine")!;
		append(args, "--wrapper")!;
		append(args, zhen_path)!;
	};
	if (run_cmd(args, o.nocolor)) {
		if (!o.quiet) {
			cprint(C_GREEN, "OK", "Epic action complete! The Dragon Warrior delivers!", o.nocolor);
		};
	} else {
		if (!o.quiet) cprint(C_RED, "FAIL", "Epic action failed!", o.nocolor);
		os::exit(1);
	};
};

fn do_itch(o: *opts) void = {
        if (!check_tool("curl")) {
                cprint(C_RED, "ERR", "curl not found!", o.nocolor);
                os::exit(1);
        };
        const home = match (os::getenv("HOME")) {
        case let s: str => yield s;
        case void => yield "/tmp";
        };
        static let credpath: [512]u8 = [0...];
        const cpath = fmt::bsprintf(credpath, "{}/.config/hpo/itch_key", home)!;
        const apikey_raw = match (os::open(cpath)) {
        case let f: io::file =>
                static let kbuf: [256]u8 = [0...];
                const n = match (io::read(f, kbuf)) {
                case let n: size => yield n;
                case => yield 0z;
                };
                io::close(f)!;
                yield strings::fromutf8(kbuf[..n])!;
        case =>
                cprint(C_RED, "ERR", "itch.io credentials not found! Run: butler login", o.nocolor);
                os::exit(1);
        };
        const apikey = strings::trim(apikey_raw);
        const prefix = "itch:";
        const target = strings::sub(o.url, len(prefix), strings::end);
        const slash = match (strings::index(target, '/')) {
        case let i: size => yield i;
        case void =>
                cprint(C_RED, "ERR", "itch URL must be user/game format", o.nocolor);
                os::exit(1);
        };
        const user = strings::sub(target, 0, slash);
        const game = strings::sub(target, slash + 1, strings::end);
        if (!o.quiet) {
                cprint(C_BLUE, "HPO", "itch.io game detected!", o.nocolor);
                fmt::printfln("  Game: {}/{}", user, game)!;
        };
        // Fetch game ID
        static let dataurl: [512]u8 = [0...];
        const durl = fmt::bsprintf(dataurl, "https://{}.itch.io/{}/data.json", user, game)!;
        const cmd1 = exec::cmd("curl", "-sL", durl)!;
        const p1 = exec::pipe();
        exec::addfile(&cmd1, os::stdout_file, p1.1)!;
        const proc1 = exec::start(&cmd1)!;
        io::close(p1.1)!;
        static let jbuf: [4096]u8 = [0...];
        const n1 = match (io::read(p1.0, jbuf)) {
        case let n: size => yield n;
        case => yield 0z;
        };
        io::close(p1.0)!;
        exec::wait(&proc1)!;
        const json1 = strings::fromutf8(jbuf[..n1])!;
        const idkey = "\"id\":";
        const idx1 = match (strings::index(json1, idkey)) {
        case let i: size => yield i;
        case void =>
                cprint(C_RED, "ERR", "Could not find game ID", o.nocolor);
                os::exit(1);
        };
        const rest1 = strings::sub(json1, idx1 + len(idkey), strings::end);
        const comma = match (strings::index(rest1, ',')) {
        case let i: size => yield i;
        case void => yield len(rest1);
        };
        const game_id = strings::trim(strings::sub(rest1, 0, comma));
        if (!o.quiet) fmt::printfln("  Game ID: {}", game_id)!;
        // Fetch uploads
        static let upurl: [512]u8 = [0...];
        const uurl = fmt::bsprintf(upurl, "https://api.itch.io/games/{}/uploads", game_id)!;
        static let authhdr: [256]u8 = [0...];
        const auth = fmt::bsprintf(authhdr, "Authorization: {}", apikey)!;
        const cmd2 = exec::cmd("curl", "-sL", "-H", auth, uurl)!;
        const p2 = exec::pipe();
        exec::addfile(&cmd2, os::stdout_file, p2.1)!;
        const proc2 = exec::start(&cmd2)!;
        io::close(p2.1)!;
        static let ubuf: [8192]u8 = [0...];
        const n2 = match (io::read(p2.0, ubuf)) {
        case let n: size => yield n;
        case => yield 0z;
        };
        io::close(p2.0)!;
        exec::wait(&proc2)!;
        const json2 = strings::fromutf8(ubuf[..n2])!;
        const idkey2 = "\"id\":";
        const idx2 = match (strings::index(json2, idkey2)) {
        case let i: size => yield i;
        case void =>
                cprint(C_RED, "ERR", "Could not find upload ID", o.nocolor);
                os::exit(1);
        };
        const rest2 = strings::sub(json2, idx2 + len(idkey2), strings::end);
        const comma2 = match (strings::index(rest2, ',')) {
        case let i: size => yield i;
        case void => yield len(rest2);
        };
        const upload_id = strings::trim(strings::sub(rest2, 0, comma2));
        // Get filename
        const fnkey = "\"filename\":\"";
        const fnidx = match (strings::index(json2, fnkey)) {
        case let i: size => yield i;
        case void => yield 0z;
        };
        const fnrest = strings::sub(json2, fnidx + len(fnkey), strings::end);
        const fnend = match (strings::index(fnrest, '\"')) {
        case let i: size => yield i;
        case void => yield len(fnrest);
        };
        const filename = strings::sub(fnrest, 0, fnend);
        // Build download URL and set output
        static let dlurl: [512]u8 = [0...];
        const finalurl = fmt::bsprintf(dlurl, "https://api.itch.io/uploads/{}/download?api_key={}", upload_id, apikey)!;
        static let outbuf: [512]u8 = [0...];
        o.url = finalurl;
        o.output = fmt::bsprintf(outbuf, "{}/Downloads/{}", home, filename)!;
        if (!o.quiet) {
                fmt::printfln("  Upload: {} ({})", upload_id, filename)!;
                fmt::println("")!;
        };
        do_http_custom(o);
};

fn do_gog(o: *opts) void = {
        if (!check_tool_help("lgogdownloader")) {
                cprint(C_RED, "ERR", "lgogdownloader not found! Install: sudo apt install lgogdownloader", o.nocolor);
                os::exit(1);
        };
        const prefix = "gog:";
        const gamename = strings::sub(o.url, len(prefix), strings::end);
        if (!o.quiet) {
                cprint(C_BLUE, "HPO", "GOG game detected! Using lgogdownloader backend...", o.nocolor);
                if (!o.nocolor) fmt::print(C_YELLOW)!;
                fmt::printfln("  Game: {}", gamename)!;
                if (!o.nocolor) fmt::print(C_RESET)!;
                fmt::println("")!;
                cprint(C_GREEN, "HPO", "Skadoosh! Fetching from GOG...", o.nocolor);
                fmt::println("")!;
        };
        let args: []str = alloc([], 8)!;
        defer free(args);
        append(args, "lgogdownloader")!;
        append(args, "--download")!;
        append(args, "--game")!;
        append(args, gamename)!;
        if (run_cmd(args, o.nocolor)) {
                if (!o.quiet) {
                        cprint(C_GREEN, "OK", "GOG download complete! The Dragon Warrior delivers!", o.nocolor);
                };
        } else {
                if (!o.quiet) cprint(C_RED, "FAIL", "GOG download failed!", o.nocolor);
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

		if (is_gog(o.url)) {
			do_gog(o);
			return;
		};
		if (is_itch(o.url)) {
			do_itch(o);
			return;
		};
		if (is_mega(o.url)) {
			do_mega(o);
		} else if (is_magnet(o.url)) {
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
	if (is_suno_cdn(o.url)) {
		const song_url = suno_cdn_to_song(o.url);
		const title = suno_get_title(song_url);
		const home = match (os::getenv("HOME")) {
		case let s: str =>
			yield s;
		case void =>
			yield "/tmp";
		};
		if (len(title) > 0) {
			const ext = if (strings::hassuffix(o.url, ".mp3")) ".mp3" else ".m4a";
			static let cbuf: [512]u8 = [0...];
			o.output = fmt::bsprintf(cbuf, "{}/Downloads/{}{}", home, title, ext)!;
		};
	};
	if (is_suno(o.url)) {
		const suno_orig = o.url;
		o.url = suno_to_cdn(o.url);
		const title = suno_get_title(suno_orig);
		const home = match (os::getenv("HOME")) {
		case let s: str =>
			yield s;
		case void =>
			yield "/tmp";
		};
		static let tbuf: [512]u8 = [0...];
		if (len(title) > 0) {
			o.output = fmt::bsprintf(tbuf, "{}/Downloads/{}.mp3", home, title)!;
		} else {
			o.output = default_output(o.url);
		};
		o.suno = false;
	};
	if (is_itch(o.url)) {
		do_itch(o);
		return;
	};
	if (is_gog(o.url)) {
		do_gog(o);
		return;
	};
	if (is_mega(o.url)) {
		do_mega(o);
	} else if (is_magnet(o.url)) {
		do_magnet(o);
	} else if (is_gdrive(o.url)) {
		do_gdrive(o);
	} else {
		do_http_custom(o);
	};
};


fn play_bell() void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "";
	};
	static let path_buf: [512]u8 = [0...];
	const bell_path = fmt::bsprintf(path_buf, "{}/.local/share/hpo/bell.mp3", home)!;
	if (!os::exists(bell_path)) {
		fmt::print("\a")!;
		bufio::flush(os::stdout)!;
		return;
	};
	const cmd = match (exec::cmd("mpv", "--no-video", "--really-quiet", bell_path)) {
	case let c: exec::command => yield c;
	case => return;
	};
	const null_file = match (os::open("/dev/null", fs::flag::WRONLY)) {
	case let f: io::file => yield f;
	case => return;
	};
	defer io::close(null_file)!;
	exec::addfile(&cmd, os::stdout_file, null_file)!;
	exec::addfile(&cmd, os::stderr_file, null_file)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case => return;
	};
	exec::wait(&proc)!;
};

fn print_help() void = {
	fmt::println("hpo - The Hare Download & Game Manager v3.2.1")!;
	fmt::println("")!;
	fmt::println("USAGE:")!;
	fmt::println("  hpo <url|magnet|rooster> [options]   Download mode")!;
	fmt::println("  hpo --epic <action> <game>           Epic Games launcher")!;
	fmt::println("  hpo --steam <action|alias> [arg]     Steam launcher")!;
	fmt::println("  hpo --zhen-setup [--proton]          Install Zhen engine")!;
	fmt::println("  hpo oogway                           10-min guided meditation")!;
	fmt::println("")!;
	fmt::println("DOWNLOAD OPTIONS:")!;
	fmt::println("  -o <path>       Output file or directory (default: ~/Downloads/)")!;
	fmt::println("  -r              Resume interrupted HTTP download")!;
	fmt::println("  -R <speed>      Rate limit (e.g. 500k, 2m, 1g)")!;
	fmt::println("  -u <agent>      Custom User-Agent (HTTP only)")!;
	fmt::println("  -s <mins>       Seed time after torrent (default: 0)")!;
	fmt::println("  --lock <url>    Create a Rooster link (encrypted URL)")!;
	fmt::println("  --token <tok>   Bearer token for authenticated downloads")!;
	fmt::println("  --cookie <str>  Cookie string for session-based downloads")!;
	fmt::println("  --code <key>    Secret code for Rooster links")!;
	fmt::println("  -v              Verbose output")!;
	fmt::println("  -q              Quiet mode")!;
	fmt::println("  --no-color      Disable colors")!;
	fmt::println("  -h              This help")!;
	fmt::println("")!;
	fmt::println("EPIC GAMES (via legendary + Zhen engine):")!;
	fmt::println("  hpo --epic list                    List all Epic games")!;
	fmt::println("  hpo --epic install <app|alias>     Install a game")!;
	fmt::println("  hpo --epic launch <app|alias>      Launch a game")!;
	fmt::println("")!;
	fmt::println("STEAM (via URI handler + Zhen GE-Proton):")!;
	fmt::println("  hpo --steam list                   List installed Steam games")!;
	fmt::println("  hpo --steam install <appid|alias>  Install a game")!;
	fmt::println("  hpo --steam launch <appid|alias>   Launch a game")!;
	fmt::println("  hpo --steam <alias>                Short syntax (auto-launch)")!;
	fmt::println("  Aliases stored in ~/.config/hpo/steam_aliases.txt")!;
	fmt::println("")!;
	fmt::println("ZHEN ENGINE (self-contained gaming runtime):")!;
	fmt::println("  hpo --zhen-setup                   Install umu-launcher only")!;
	fmt::println("  hpo --zhen-setup --proton          Also install GE-Proton10-34")!;
	fmt::println("")!;
	fmt::println("EXAMPLES:")!;
	fmt::println("  hpo https://example.com/file.zip")!;
	fmt::println("  hpo --epic launch celeste")!;
	fmt::println("  hpo --steam kao                    Launch Kao the Kangaroo")!;
	fmt::println("  hpo --steam launch 1370140")!;
	fmt::println("  hpo --zhen-setup --proton")!;
	fmt::println("  hpo oogway                         Find inner peace")!;
	fmt::println("")!;
	fmt::println("DOWNLOAD BACKENDS:")!;
	fmt::println("  HTTP/HTTPS/FTP  -> curl (dragon progress bar)")!;
	fmt::println("  Google Drive    -> gdown")!;
	fmt::println("  magnet:         -> aria2c")!;
	fmt::println("  rooster:        -> openssl (AES-256-CBC)")!;
	fmt::println("  Suno music      -> curl + ffmpeg (auto MP3 convert)")!;
	fmt::println("")!;
	fmt::println("Skadoosh! The Dragon Warrior delivers.")!;
};
fn do_oogway(o: *opts) void = {

	const messages: [](uint, str) = [
		(0u,   "Welcome, young one. Come, sit with me."),
		(20u,  "Let your shoulders fall. Release the day's burdens."),
		(50u,  "Breathe like the mountain breathes. Slow. Steady."),
		(90u,  "Your mind is like this water. When agitated, it is hard to see."),
		(140u, "But if you allow it to settle... the answer becomes clear."),
		(200u, "There are no accidents. You are exactly where you need to be."),
		(260u, "Halfway. You are doing well. The path itself is the goal."),
		(320u, "Yesterday is history. Tomorrow is a mystery."),
		(360u, "But today... today is a gift. That is why it is called the present."),
		(420u, "There is just news. There is no good or bad."),
		(480u, "The mark of a true hero is humility."),
		(540u, "Soon you will return. Carry this stillness with you."),
		(580u, "Slowly... begin to come back to the world."),
		(595u, "Open your eyes when you are ready."),
	];

	const total_seconds = o.oogway_sec;
	let elapsed = 0u;
	let msg_idx = 0z;

	fmt::print("\x1b[2J\x1b[H")!;
	fmt::println("")!;
	fmt::println("                    \x1b[33m🐢  HPO OOGWAY  🐢\x1b[0m")!;
	fmt::println("")!;
	fmt::println("                  \x1b[36m┏━━━━━━━━━━━━━━━━━━━━━━┓\x1b[0m")!;
	fmt::println("                  \x1b[36m┃  Inner Peace Session  ┃\x1b[0m")!;
	fmt::println("                  \x1b[36m┗━━━━━━━━━━━━━━━━━━━━━━┛\x1b[0m")!;
	fmt::println("")!;
	fmt::println("                         \x1b[32m___\x1b[0m")!;
	fmt::println("                     \x1b[32m,uadOOOOOOOba.,\x1b[0m")!;
	fmt::println("                  \x1b[32m,uOOOOOOOOOOOOOOOb,\x1b[0m")!;
	fmt::println("                \x1b[32m,OOOOOOOOOOOOOOOOOOOOb,\x1b[0m")!;
	fmt::println("               \x1b[32mdOOOOOOOOO\x1b[33m_,_\x1b[32mOOOOOOOOOb\x1b[0m")!;
	fmt::println("              \x1b[32mdOOOOOOOO\x1b[33m( o o )\x1b[32mOOOOOOOOb\x1b[0m")!;
	fmt::println("              \x1b[32mOOOOOOOO\x1b[33m  \\_/  \x1b[32mOOOOOOOOO\x1b[0m")!;
	fmt::println("              \x1b[32m`OOOOOOOOOOOOOOOOOOOOOO\x1b[0m'")!;
	fmt::println("                \x1b[32m`OOOOOOOOOOOOOOOOOO'\x1b[0m")!;
	fmt::println("")!;

	// Start-bell: lille ding
	play_bell();
	time::sleep(500 * time::MILLISECOND);

	fmt::println("")!;
	fmt::println("        \x1b[36mPress Ctrl+C to end early\x1b[0m")!;
	fmt::println("")!;

	for (elapsed < total_seconds) {
		const remaining = total_seconds - elapsed;
		const minutes = remaining / 60;
		const seconds = remaining % 60;

		if (msg_idx < len(messages) && messages[msg_idx].0 == elapsed) {
			fmt::println("")!;
			fmt::printfln("        \x1b[35m\"{}\"\x1b[0m", messages[msg_idx].1)!;
			fmt::println("                              \x1b[33m— Oogway\x1b[0m")!;
			fmt::println("")!;
			msg_idx += 1;
		};

		const breath_phase = elapsed % 12u;
		const breath_label = if (breath_phase < 4u) "\x1b[34mBreathe in...\x1b[0m  "
			else if (breath_phase < 8u) "\x1b[36mHold...      \x1b[0m  "
			else "\x1b[34mBreathe out..\x1b[0m  ";

		const bar_pos = if (breath_phase < 4u) breath_phase * 2u
			else if (breath_phase < 8u) 8u
			else 8u - (breath_phase - 8u) * 2u;

		let bar_str = strings::concat("[")!;
		defer free(bar_str);
		let bi = 0u;
		for (bi < 8u; bi += 1) {
			const old = bar_str;
			if (bi < bar_pos) {
				bar_str = strings::concat(old, "●")!;
			} else {
				bar_str = strings::concat(old, "○")!;
			};
			free(old);
		};
		const closed = strings::concat(bar_str, "]")!;
		defer free(closed);

		const min_str = if (minutes < 10) "0" else "";
		const sec_str = if (seconds < 10) "0" else "";
		fmt::printf("\r  \x1b[33m{}{}:{}{}\x1b[0m  {}  \x1b[32m{}\x1b[0m   ",
			min_str, minutes, sec_str, seconds, breath_label, closed)!;
		bufio::flush(os::stdout)!;

		time::sleep(1 * time::SECOND);
		elapsed += 1;
	};

	fmt::println("")!;
	fmt::println("")!;
	fmt::println("")!;

	// Triple bell ved slutning
	let b = 0u;
	for (b < 3u; b += 1) {
		play_bell();
		time::sleep(800 * time::MILLISECOND);
	};

	fmt::println("                       \x1b[33m🔔  Ding...  🔔\x1b[0m")!;
	fmt::println("")!;
	fmt::println("        \x1b[32mInner peace achieved. Skadoosh.\x1b[0m")!;
	fmt::println("                              \x1b[33m— Master Oogway\x1b[0m")!;
	fmt::println("")!;
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
                token   = "",
                cookie  = "",
		epic    = false,
		epic_cmd = "",
		steam   = false,
		steam_cmd = "",
		zhen_setup = false,
		zhen_proton = false,
		oogway = false,
		oogway_sec = 600u,
                suno    = false,
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
                } else if (a == "--token") {
                        i += 1;
                        if (i >= len(args)) {
                                fmt::errorfln("Error: --token requires a value")!;
                                os::exit(1);
                        };
                } else if (a == "--epic") {
                        i += 1;
                        if (i >= len(args)) {
                                fmt::errorfln("Error: --epic requires install|launch|list")!;
                                os::exit(1);
                        };
                        o.epic = true;
                        o.epic_cmd = args[i];
                } else if (a == "--steam") {
                        i += 1;
                        if (i >= len(args)) {
                                fmt::errorfln("Error: --steam requires launch|list|install")!;
                                os::exit(1);
                        };
                        o.steam = true;
                        o.steam_cmd = args[i];
                } else if (a == "--zhen-setup") {
                        o.zhen_setup = true;
                } else if (a == "--proton") {
                        o.zhen_proton = true;
                } else if (a == "oogway") {
                        o.oogway = true;
                        // Check om næste arg er et tal (custom varighed i sek)
                        if (i + 1 < len(args)) {
                                const next = strings::toutf8(args[i + 1]);
                                let is_number = len(next) > 0;
                                let j = 0z;
                                for (j < len(next); j += 1) {
                                        const ch = next[j];
                                        if (ch < '0': u8 || ch > '9': u8) {
                                                is_number = false;
                                                break;
                                        };
                                };
                                if (is_number) {
                                        let n = 0u;
                                        let k = 0z;
                                        for (k < len(next); k += 1) {
                                                n = n * 10u + (next[k] - '0': u8): uint;
                                        };
                                        o.oogway_sec = n;
                                        i += 1;
                                };
                        };
                } else if (a == "--cookie") {
                        i += 1;
                        if (i >= len(args)) {
                                fmt::errorfln("Error: --cookie requires a value")!;
                                os::exit(1);
                        };
                        o.cookie = args[i];
                        o.token = args[i];
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
	if (o.oogway) {
		do_oogway(&o);
		return;
	};
	if (o.zhen_setup) {
		do_zhen_setup(&o);
		return;
	};
	if (o.steam) {
		do_steam(&o, o.url);
		return;
	};
	if (o.epic) {
		do_epic(&o, o.url);
		return;
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
