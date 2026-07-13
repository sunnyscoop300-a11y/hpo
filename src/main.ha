use fmt;
use io;
use os;
use os::exec;
use strings;
use bufio;
use strconv;
use time;
use fs;

def VERSION = "4.25.0";

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
	roz: bool,
	roz_city: str,
	roz_day: str,
	shifu: bool,
	shifu_city: str,
	chameleon: bool,
	chameleon_action: str,
	chameleon_target: str,
	chameleon_epic: bool,
	tigress: bool,
	piyoko: bool,
	piyoko_action: str,
	piyoko_target: str,
	xp: bool,
	xp_action: str,
	xp_rom: str,
	tailung: bool,
	tailung_urls: []str,
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
	do_full_setup: bool,
	zhen_install: bool,
	zhen_force: bool,
	ping: bool,
	mantis: bool,
	viper: bool,
	viper_setup: bool,
	monkey: bool,
	monkey_setup: bool,
	crane: bool,
	crane_arg: str,
	crane_arg2: str,
	kai: bool,
	kai_arg: str,
	doctor: bool,
	ping_setup: bool,
	bnet: bool,
	bnet_setup: bool,
	zhen_force_target: str,
	zhen_install_target: str,
	zhen_update: bool,
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

// Som run_cmd, men dæmper barnets stdout/stderr (til /dev/null)
fn run_cmd_quiet(args: []str, nc: bool) bool = {
	const cmd = match (exec::cmd(args[0], args[1..]...)) {
	case let c: exec::command => yield c;
	case => return false;
	};
	const devnull = match (os::open("/dev/null", fs::flag::WRONLY)) {
	case let f: io::file => yield f;
	case => yield exec::nullfd;
	};
	exec::addfile(&cmd, os::stdout_file, devnull)!;
	exec::addfile(&cmd, os::stderr_file, devnull)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case => return false;
	};
	const st = match (exec::wait(&proc)) {
	case let s: exec::status => yield s;
	case => return false;
	};
	match (exec::exit(&st)) {
	case let e: exec::exited => return e == 0;
	case => return false;
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
		piyoko_earn(1);
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
			piyoko_earn(1);
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
		piyoko_earn(1);
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
		piyoko_earn(1);
			fmt::printfln("  Saved to: {}", o.output)!;
		};
	} else {
		if (!o.quiet) {
			cprint(C_RED, "FAIL", "Mega download failed!", o.nocolor);
		};
		os::exit(1);
	};
};

fn do_zhen_update(o: *opts) void = {
	cprint(C_BLUE, "ZHEN", "Checking for new Proton-GE release...", o.nocolor);
	fmt::println("")!;

	// Hent latest release JSON fra GitHub API
	let curl_args: []str = alloc([], 8)!;
	defer free(curl_args);
	append(curl_args, "curl")!;
	append(curl_args, "-s")!;
	append(curl_args, "-L")!;
	append(curl_args, "-A")!;
	append(curl_args, "hpo-zhen/1.0")!;
	append(curl_args, "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest")!;

	const cmd = match (exec::cmd(curl_args[0], curl_args[1..]...)) {
	case let c: exec::command => yield c;
	case => {
		cprint(C_RED, "ZHEN", "Failed to start curl", o.nocolor);
		return;
	};
	};
	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case => return;
	};
	io::close(pipe.1)!;
	static let json_buf: [16384]u8 = [0...];
	const n = match (io::read(pipe.0, json_buf)) {
	case let nn: size => yield nn;
	case => yield 0z;
	};
	io::close(pipe.0)!;
	exec::wait(&proc)!;
	const json = strings::fromutf8(json_buf[..n])!;

	// Find "tag_name":"GE-ProtonX-Y"
	const tag_start = match (strings::index(json, "\"tag_name\":\"")) {
	case let i: size => yield i + 12;
	case void => {
		cprint(C_RED, "ZHEN", "Could not parse latest release", o.nocolor);
		return;
	};
	};
	const tag_rest = strings::sub(json, tag_start, strings::end);
	const tag_end = match (strings::index(tag_rest, "\"")) {
	case let i: size => yield i;
	case void => return;
	};
	const latest_tag = strings::sub(tag_rest, 0, tag_end);

	cprint(C_YELLOW, "ZHEN", fmt::asprintf("Latest GE-Proton: {}", latest_tag)!, o.nocolor);

	// Tjek om vi allerede har den
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let zhen_dir_buf: [512]u8 = [0...];
	const latest_path = fmt::bsprintf(zhen_dir_buf, "{}/.local/share/hpo/zhen/proton/{}", home, latest_tag)!;
	if (os::exists(latest_path)) {
		cprint(C_GREEN, "ZHEN", "Already up to date!", o.nocolor);
		return;
	};

	// Download tarball
	cprint(C_BLUE, "ZHEN", "Downloading new Proton-GE...", o.nocolor);
	static let url_buf: [512]u8 = [0...];
	const url = fmt::bsprintf(url_buf, "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/{}/{}.tar.gz", latest_tag, latest_tag)!;
	static let tar_buf: [512]u8 = [0...];
	const tar_path = fmt::bsprintf(tar_buf, "/tmp/{}.tar.gz", latest_tag)!;
	let dl_args: []str = alloc([], 6)!;
	defer free(dl_args);
	append(dl_args, "curl")!;
	append(dl_args, "-L")!;
	append(dl_args, "-#")!;
	append(dl_args, "-o")!;
	append(dl_args, tar_path)!;
	append(dl_args, url)!;
	if (!run_cmd(dl_args, o.nocolor)) {
		cprint(C_RED, "ZHEN", "Download failed", o.nocolor);
		return;
	};

	// Pak ud til ~/.local/share/hpo/zhen/proton/
	cprint(C_BLUE, "ZHEN", "Extracting...", o.nocolor);
	static let dest_buf: [512]u8 = [0...];
	const dest = fmt::bsprintf(dest_buf, "{}/.local/share/hpo/zhen/proton", home)!;
	os::mkdirs(dest, 0o755)!;
	let tar_args: []str = alloc([], 6)!;
	defer free(tar_args);
	append(tar_args, "tar")!;
	append(tar_args, "-xzf")!;
	append(tar_args, tar_path)!;
	append(tar_args, "-C")!;
	append(tar_args, dest)!;
	if (!run_cmd(tar_args, o.nocolor)) {
		cprint(C_RED, "ZHEN", "Extraction failed", o.nocolor);
		return;
	};

	// Cleanup
	os::remove(tar_path): void;
	cprint(C_GREEN, "ZHEN", fmt::asprintf("{} installed! Restart Steam to use it.", latest_tag)!, o.nocolor);
	fmt::println("")!;
	fmt::println("  NB: Edit STEAM_COMPAT_TOOL_OVERRIDE i src/main.ha if you want")!;
	fmt::println("      hpo to force this new version automatically.")!;
};

fn do_setup(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_BLUE)!;
	fmt::println("
   ===========================================
    HPO FULL SETUP - Installing all the things
   ===========================================
")!;
	if (!o.nocolor) fmt::print(C_RESET)!;

	// 1) Update package lists first (avoids stale-cache 404 errors)
	cprint(C_YELLOW, "SETUP", "Updating package lists (apt update)...", o.nocolor);
	let aptup: []str = alloc([], 3)!;
	defer free(aptup);
	append(aptup, "sudo")!;
	append(aptup, "apt")!;
	append(aptup, "update")!;
	let _ = run_cmd(aptup, o.nocolor);

	// 2) System packages via apt (kræver sudo)
	cprint(C_YELLOW, "SETUP", "Installing system packages (needs sudo)...", o.nocolor);
	let apt: []str = alloc([], 12)!;
	defer free(apt);
	append(apt, "sudo")!;
	append(apt, "apt")!;
	append(apt, "install")!;
	append(apt, "-y")!;
	append(apt, "curl")!;
	append(apt, "aria2")!;
	append(apt, "megatools")!;
	append(apt, "lgogdownloader")!;
	append(apt, "python3-pip")!;
	append(apt, "pipx")!;
	let _ = run_cmd(apt, o.nocolor);

	// 2) pip/pipx tools
	cprint(C_YELLOW, "SETUP", "Installing gdown (pip)...", o.nocolor);
	let pg: []str = alloc([], 5)!;
	defer free(pg);
	append(pg, "pip")!;
	append(pg, "install")!;
	append(pg, "--user")!;
	append(pg, "--break-system-packages")!;
	append(pg, "gdown")!;
	let _ = run_cmd(pg, o.nocolor);

	cprint(C_YELLOW, "SETUP", "Installing legendary (pipx)...", o.nocolor);
	let pl: []str = alloc([], 3)!;
	defer free(pl);
	append(pl, "pipx")!;
	append(pl, "install")!;
	append(pl, "legendary-gl")!;
	let _ = run_cmd(pl, o.nocolor);

	// 3) Zhen engine: umu + GE-Proton + SteamCMD
	cprint(C_YELLOW, "SETUP", "Setting up Zhen engine (umu + GE-Proton + SteamCMD)...", o.nocolor);
	o.zhen_proton = true;
	do_zhen_setup(o);

	// 3b) Retro-emulatorer til Piyoko Arcade (hpo xp)
	cprint(C_YELLOW, "SETUP", "Installing retro emulators (MAME, mGBA, fceux)...", o.nocolor);
	let emu: []str = alloc([], 7)!;
	defer free(emu);
	append(emu, "sudo")!;
	append(emu, "apt")!;
	append(emu, "install")!;
	append(emu, "-y")!;
	append(emu, "mame")!;
	append(emu, "fceux")!;
	append(emu, "mgba-sdl")!;
	let _ = run_cmd(emu, o.nocolor);
	// 3c) DuckStation (PSX) AppImage + arcade-mapper
	cprint(C_YELLOW, "SETUP", "Installing DuckStation + arcade folders...", o.nocolor);
	match (os::getenv("HOME")) {
		case let h: str =>
			let mk = fmt::asprintf("mkdir -p {}/.local/share/hpo/arcade/roms {}/.local/share/hpo/arcade/nes {}/.local/share/hpo/arcade/snes {}/.local/share/hpo/arcade/genesis {}/.local/share/hpo/arcade/gb {}/.local/share/hpo/arcade/psx {}/.local/share/hpo/arcade/bios", h, h, h, h, h, h, h)!;
			defer free(mk);
			let mkargs: []str = ["sh", "-c", mk];
			let _ = run_cmd(mkargs, o.nocolor);
			let duck = fmt::asprintf("{}/.local/share/hpo/duckstation.AppImage", h)!;
			defer free(duck);
			let dl: []str = ["curl", "-L", "-o", duck, "https://github.com/stenzek/duckstation/releases/download/latest/duckstation-x64.AppImage"];
			let _ = run_cmd(dl, o.nocolor);
			let chm: []str = ["chmod", "+x", duck];
			let _ = run_cmd(chm, o.nocolor);
		case => void;
	};
	// 4) Summary
	fmt::println("")!;
	if (!o.nocolor) fmt::print(C_GREEN)!;
	fmt::println("   ===========================================")!;
	fmt::println("    HPO SETUP COMPLETE - Skadoosh!")!;
	fmt::println("   ===========================================")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	fmt::println("")!;
	fmt::println("  Installed checks:")!;
	fmt::printfln("   curl ........ {}", if (check_tool("curl")) "OK" else "MISSING")!;
	fmt::printfln("   aria2c ...... {}", if (check_tool("aria2c")) "OK" else "MISSING")!;
	fmt::printfln("   megadl ...... {}", if (check_tool("megadl")) "OK" else "MISSING")!;
	fmt::printfln("   gdown ....... {}", if (check_tool("gdown")) "OK" else "MISSING")!;
	fmt::printfln("   legendary ... {}", if (check_tool("legendary")) "OK" else "MISSING")!;
	let scmd = false;
	match (os::getenv("HOME")) {
	case let h: str =>
		let p = fmt::asprintf("{}/.local/share/hpo/steamcmd/steamcmd.sh", h)!;
		defer free(p);
		scmd = os::exists(p);
	case => void;
	};
	fmt::printfln("   steamcmd .... {}", if (scmd) "OK" else "MISSING")!;
	fmt::println("")!;
	fmt::println("  Set your Steam account for 'zhen install':")!;
	fmt::println("   echo 'youruser' > ~/.config/hpo/steam_account.txt")!;
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
		const proton_target = fmt::bsprintf(proton_target_buf, "{}/GE-Proton11-1", proton_dir)!;

		if (os::exists(proton_target)) {
			if (!o.quiet) cprint(C_YELLOW, "ZHEN", "GE-Proton11-1 already installed, skipping.", o.nocolor);
		} else {
			if (!o.quiet) {
				fmt::println("")!;
				cprint(C_BLUE, "ZHEN", "Downloading GE-Proton11-1 (~700MB, patience grasshopper)...", o.nocolor);
			};
			os::mkdir(proton_dir, 0o755): void;
			static let proton_tar_buf: [512]u8 = [0...];
			const proton_tar = fmt::bsprintf(proton_tar_buf, "{}/proton.tar.gz", proton_dir)!;
			const proton_url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-1/GE-Proton11-1.tar.gz";

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
					cprint(C_GREEN, "ZHEN", "GE-Proton11-1 installed! Full independence achieved.", o.nocolor);
					fmt::printfln("  Path: {}", proton_target)!;
				};
			} else {
				cprint(C_RED, "FAIL", "Proton not found after extract!", o.nocolor);
				os::exit(1);
			};
		};
	};

	// Install SteamCMD til zhen install
	install_steamcmd(o);
};

fn install_steamcmd(o: *opts) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let dir_buf: [512]u8 = [0...];
	const scmd_dir = fmt::bsprintf(dir_buf, "{}/.local/share/hpo/steamcmd", home)!;
	static let sh_buf: [512]u8 = [0...];
	const scmd_sh = fmt::bsprintf(sh_buf, "{}/steamcmd.sh", scmd_dir)!;
	if (os::exists(scmd_sh)) {
		if (!o.quiet) cprint(C_YELLOW, "ZHEN", "SteamCMD already installed, skipping.", o.nocolor);
		return;
	};
	if (!o.quiet) {
		fmt::println("")!;
		cprint(C_BLUE, "ZHEN", "Installing SteamCMD...", o.nocolor);
	};
	os::mkdirs(scmd_dir, 0o755)!;
	static let tar_buf: [512]u8 = [0...];
	const tar_path = fmt::bsprintf(tar_buf, "{}/steamcmd.tar.gz", scmd_dir)!;
	const url = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz";
	let dl: []str = alloc([], 5)!;
	defer free(dl);
	append(dl, "curl")!;
	append(dl, "-L")!;
	append(dl, "-o")!;
	append(dl, tar_path)!;
	append(dl, url)!;
	if (!run_cmd(dl, o.nocolor)) {
		cprint(C_RED, "FAIL", "SteamCMD download failed!", o.nocolor);
		return;
	};
	let ex: []str = alloc([], 5)!;
	defer free(ex);
	append(ex, "tar")!;
	append(ex, "-xzf")!;
	append(ex, tar_path)!;
	append(ex, "-C")!;
	append(ex, scmd_dir)!;
	if (!run_cmd(ex, o.nocolor)) {
		cprint(C_RED, "FAIL", "SteamCMD extract failed!", o.nocolor);
		return;
	};
	os::remove(tar_path): void;
	if (os::exists(scmd_sh)) {
		if (!o.quiet) cprint(C_GREEN, "ZHEN", "SteamCMD installed!", o.nocolor);
	} else {
		cprint(C_RED, "FAIL", "steamcmd.sh not found after extract!", o.nocolor);
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

fn steam_game_name_linux(appid: str) str = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => return "";
	};
	// SteamCMD-install: .acf ligger indlejret i common/<appid>/steamapps/
	static let nested_buf: [768]u8 = [0...];
	const nested = fmt::bsprintf(nested_buf,
		"{}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/{}/steamapps/appmanifest_{}.acf",
		home, appid, appid)!;
	match (os::open(nested)) {
	case let f: io::file =>
		static let nbuf: [8192]u8 = [0...];
		const n = match (io::read(f, nbuf)) {
		case let z: size => yield z;
		case => yield 0z;
		};
		io::close(f)!;
		if (n > 0) {
			const content = strings::fromutf8(nbuf[..n])!;
			const key = "\"name\"";
			match (strings::index(content, key)) {
			case let ki: size =>
				const rest = strings::sub(content, ki + len(key), strings::end);
				match (strings::index(rest, '"')) {
				case let q1: size =>
					const after = strings::sub(rest, q1 + 1, strings::end);
					match (strings::index(after, '"')) {
					case let q2: size =>
						return strings::dup(strings::sub(after, 0, q2))!;
					case void => void;
					};
				case void => void;
				};
			case void => void;
			};
		};
	case => void;
	};
	// Mulige Steam steamapps-stier (Flatpak, native, .steam)
	const bases: [_]str = [
		"/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps",
		"/.local/share/Steam/steamapps",
		"/.steam/steam/steamapps",
		"/.steam/debian-installation/steamapps",
	];
	for (let i = 0z; i < len(bases); i += 1) {
		static let pbuf: [512]u8 = [0...];
		const p = fmt::bsprintf(pbuf, "{}{}/appmanifest_{}.acf", home, bases[i], appid)!;
		match (os::open(p)) {
		case let f: io::file =>
			static let rbuf: [8192]u8 = [0...];
			const n = match (io::read(f, rbuf)) {
			case let z: size => yield z;
			case => yield 0z;
			};
			io::close(f)!;
			if (n == 0) continue;
			const content = match (strings::fromutf8(rbuf[..n])) {
			case let s: str => yield s;
			case => continue;
			};
			// Find "name" felt
			const key = "\"name\"";
			const ki = match (strings::index(content, key)) {
			case let x: size => yield x;
			case void => continue;
			};
			const rest = strings::sub(content, ki + len(key), strings::end);
			// Find første " efter key, så næste "
			const q1 = match (strings::index(rest, '"')) {
			case let x: size => yield x;
			case void => continue;
			};
			const after = strings::sub(rest, q1 + 1, strings::end);
			const q2 = match (strings::index(after, '"')) {
			case let x: size => yield x;
			case void => continue;
			};
			const name = strings::sub(after, 0, q2);
			return strings::dup(name)!;
		case => continue;
		};
	};
	return "";
};

fn steam_game_name(appid: str) str = {
	if (!is_wsl()) return steam_game_name_linux(appid);
	const ps_tmpl = `[Console]::OutputEncoding=[Text.Encoding]::UTF8; $lf=Get-Content 'C:\\Program Files (x86)\\Steam\\steamapps\\libraryfolders.vdf' -Raw -Encoding UTF8; $paths=[regex]::Matches($lf,'"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\','\' }; foreach($p in $paths){ $f=Join-Path $p 'steamapps\\appmanifest___APPID__.acf'; if(Test-Path $f){ $t=Get-Content $f -Raw -Encoding UTF8; [regex]::Match($t,'"name"\s+"([^"]+)"').Groups[1].Value } }`;
	const ps = strings::replace(ps_tmpl, "__APPID__", appid)!;
	defer free(ps);
	const cmd = match (exec::cmd("powershell.exe", "-NoProfile", "-Command", ps)) {
	case let c: exec::command => yield c;
	case => return "";
	};
	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	exec::addfile(&cmd, os::stderr_file, exec::nullfd)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case =>
		io::close(pipe.0)!;
		io::close(pipe.1)!;
		return "";
	};
	io::close(pipe.1)!;
	static let nbuf: [256]u8 = [0...];
	const n = match (io::read(pipe.0, nbuf)) {
	case let n: size => yield n;
	case => yield 0z;
	};
	io::close(pipe.0)!;
	exec::wait(&proc)!;
	if (n == 0) return "";
	const s = match (strings::fromutf8(nbuf[..n])) {
	case let s: str => yield s;
	case => return "";
	};
	const t = strings::trim(s);
	if (len(t) == 0) return "";
	return match (strings::dup(t)) {
	case let d: str => yield d;
	case => yield "";
	};
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
		if (is_wsl()) {
			const ps_list = `Get-ChildItem 'C:\\Program Files (x86)\\Steam\\steamapps\\appmanifest_*.acf' | ForEach-Object { $t=Get-Content $_ -Raw; $a=[regex]::Match($t,'"appid"\s+"(\d+)"').Groups[1].Value; $n=[regex]::Match($t,'"name"\s+"([^"]+)"').Groups[1].Value; '  ' + $n + '  [' + $a + ']' }`;
			let ps_args: []str = alloc([], 4)!;
			defer free(ps_args);
			append(ps_args, "powershell.exe")!;
			append(ps_args, "-NoProfile")!;
			append(ps_args, "-Command")!;
			append(ps_args, ps_list)!;
			let _ = run_cmd(ps_args, o.nocolor);
			return;
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
	if (o.steam_cmd != "list" && o.steam_cmd != "install" && o.steam_cmd != "launch" && o.steam_cmd != "wishlist" && o.steam_cmd != "validate" && o.steam_cmd != "verify" && o.steam_cmd != "page" && o.steam_cmd != "store" && len(target) == 0) {
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

	// Hvis hverken AppID-tal eller kendt alias, foreslå nærmeste
	if (!is_numeric(appid)) {
		cprint(C_RED, "FOXFIRE", "Unknown game alias", o.nocolor);
		fmt::printfln("  '{}' is not a known alias or AppID.", target)!;
		suggest_alias(target, "steam");
		return;
	};

	static let uri_buf: [512]u8 = [0...];
	const action =
		if (o.steam_cmd == "install") "install"
		else if (o.steam_cmd == "wishlist") "store"
		else if (o.steam_cmd == "page") "store"
		else if (o.steam_cmd == "store") "store"
		else if (o.steam_cmd == "validate") "validate"
		else if (o.steam_cmd == "verify") "validate"
		else "rungameid";
	const uri = fmt::bsprintf(uri_buf, "steam://{}/{}", action, appid)!;

	// WSL detection: hvis vi er på WSL, bridge til Windows Steam i stedet
	const on_wsl = is_wsl();

	// Auto-link Zhen's GE-Proton til Steam (kun på native Linux, ikke WSL)
	static let zhen_src_buf: [512]u8 = [0...];
	const zhen_proton_src = fmt::bsprintf(zhen_src_buf, "{}/.local/share/hpo/zhen/proton/GE-Proton11-1", home)!;
	static let steam_compat_buf: [512]u8 = [0...];
	const steam_compat_dir = fmt::bsprintf(steam_compat_buf, "{}/.var/app/com.valvesoftware.Steam/.local/share/Steam/compatibilitytools.d", home)!;
	static let steam_target_buf: [512]u8 = [0...];
	const steam_target = fmt::bsprintf(steam_target_buf, "{}/GE-Proton11-1", steam_compat_dir)!;
	if (!on_wsl && os::exists(zhen_proton_src) && !os::exists(steam_target)) {
		if (!o.quiet) cprint(C_YELLOW, "ZHEN", "Linking Zhen's GE-Proton to Steam...", o.nocolor);
		os::mkdir(steam_compat_dir, 0o755): void;
		let ln_args: []str = alloc([], 5)!;
		defer free(ln_args);
		append(ln_args, "cp")!;
		append(ln_args, "-r")!;
		append(ln_args, zhen_proton_src)!;
		append(ln_args, steam_target)!;
		let _ = run_cmd(ln_args, o.nocolor);
	};

	if (!o.quiet) {
		cprint(C_BLUE, "FOXFIRE", "Steam game detected!", o.nocolor);
		if (!o.nocolor) fmt::print(C_YELLOW)!;
		const gname = steam_game_name(appid);
		if (len(gname) > 0) fmt::printfln("  Game:   {}", gname)!;
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
	// ZHEN: Force GE-Proton som default compatibility tool
	if (!on_wsl && os::exists(steam_target)) {
		os::setenv("STEAM_COMPAT_TOOL_OVERRIDE", "GE-Proton11-1")!;
	};

	// ZHEN umu-launch: ægte GE-Proton for Steam-spil på Linux (launch only)
	if (!on_wsl && action == "rungameid" && os::exists(zhen_proton_src)) {
		const gamedir = steam_installdir(appid);
		if (len(gamedir) > 0) {
			const exe = find_game_exe(gamedir);
			// DRM-beskyttede spil kan ikke launches via umu - lad Steam h\u00e5ndtere dem
			let is_drm = match (strings::index(exe, "DRM")) {
			case size => yield true;
			case void => yield false;
			};
			// requires-native liste: EA/launcher-spil hvis exe ikke siger "DRM"
			// men som alligevel skal via steam:// (fx Alice = 19680)
			if (!is_drm) {
				static let rn_buf: [512]u8 = [0...];
				const rn_path = fmt::bsprintf(rn_buf, "{}/.config/hpo/steam_requires_native.txt", home)!;
				match (os::open(rn_path)) {
				case let f: io::file =>
					defer io::close(f)!;
					const rn_data = match (io::drain(f)) {
					case let d: []u8 => yield d;
					case io::error => yield [] : []u8;
					};
					defer free(rn_data);
					const rn_str = strings::fromutf8(rn_data)!;
					const lines = strings::split(rn_str, "\n")!;
					defer free(lines);
					for (let i = 0z; i < len(lines); i += 1) {
						const ln = strings::trim(lines[i]);
						if (ln == appid) {
							is_drm = true;
							break;
						};
					};
				case fs::error => void;
				};
			};
			if (is_drm) {
				if (!o.quiet) {
					cprint(C_YELLOW, "ZHEN", "DRM-protected game detected.", o.nocolor);
					cprint(C_YELLOW, "ZHEN", "Using Steam launch (DRM needs the Steam client).", o.nocolor);
					fmt::println("")!;
				};
			};
			if (len(exe) > 0 && !is_drm) {
				static let umu_buf: [512]u8 = [0...];
				const umu = fmt::bsprintf(umu_buf, "{}/.local/share/hpo/zhen/umu-run", home)!;
				if (os::exists(umu)) {
					static let pfx_buf: [512]u8 = [0...];
					const pfx = fmt::bsprintf(pfx_buf, "{}/.proton-prefix-steam/{}", home, appid)!;
					os::mkdirs(pfx, 0o755)!;
					os::setenv("WINEPREFIX", pfx)!;
					os::setenv("STEAM_COMPAT_DATA_PATH", pfx)!;
					static let sci_buf: [512]u8 = [0...];
					const sci = fmt::bsprintf(sci_buf, "{}/.local/share/hpo/zhen", home)!;
					os::setenv("STEAM_COMPAT_CLIENT_INSTALL_PATH", sci)!;
					os::setenv("PROTONPATH", zhen_proton_src)!;
					os::setenv("GAMEID", "umu-0")!;
					os::setenv("STORE", "none")!;
					os::setenv("DXVK_ASYNC", "1")!;
					os::setenv("WINEESYNC", "1")!;
					os::setenv("WINEFSYNC", "1")!;
					if (!o.quiet) {
						cprint(C_YELLOW, "ZHEN", "Zhen engine awakening with GE-Proton11-1...", o.nocolor);
						fmt::printfln("  Exe: {}", exe)!;
						fmt::println("")!;
					};
					let uargs: []str = alloc([], 2)!;
					defer free(uargs);
					append(uargs, umu)!;
					append(uargs, exe)!;
					if (run_cmd_quiet(uargs, o.nocolor)) {
						if (!o.quiet) cprint(C_GREEN, "OK", "Game launched with GE-Proton! Skadoosh!", o.nocolor);
					} else {
						if (!o.quiet) cprint(C_RED, "FAIL", "umu launch failed!", o.nocolor);
					};
					return;
				};
			};
		};
	};

	let steam_args: []str = alloc([], 6)!;
	defer free(steam_args);
	if (on_wsl) {
		static let steam_ps_buf: [640]u8 = [0...];
		const steam_ps = fmt::bsprintf(steam_ps_buf, "Start-Process '{}'", uri)!;
		append(steam_args, "powershell.exe")!;
		append(steam_args, "-NoProfile")!;
		append(steam_args, "-Command")!;
		append(steam_args, steam_ps)!;
	} else if (action == "rungameid" && check_tool("xdg-open")) {
		// Brug xdg-open for at sende URI til den KØRENDE Steam (undgår dobbelt-Steam)
		append(steam_args, "xdg-open")!;
		append(steam_args, uri)!;
	} else if (check_tool("steam")) {
		append(steam_args, "steam")!;
		append(steam_args, uri)!;
	} else {
		append(steam_args, "flatpak")!;
		append(steam_args, "run")!;
		// ZHEN: Pass GE-Proton override into Flatpak sandbox
		if (os::exists(steam_target)) {
			append(steam_args, "--env=STEAM_COMPAT_TOOL_OVERRIDE=GE-Proton11-1")!;
		};
		append(steam_args, "com.valvesoftware.Steam")!;
		append(steam_args, uri)!;
	};

	if (run_cmd(steam_args, o.nocolor)) {
		if (!o.quiet) cprint(C_GREEN, "OK", "Steam action complete! Vroom vroom!", o.nocolor);
		if (!o.quiet && !on_wsl && action == "install") {
			fmt::println("")!;
			cprint(C_YELLOW, "ZHEN", "Steam is downloading the game.", o.nocolor);
			cprint(C_YELLOW, "ZHEN", "When it's done, launch with GE-Proton:", o.nocolor);
			fmt::printfln("  hpo --steamfoxfire {}", target)!;
		};
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
		static let epic_ps_buf: [640]u8 = [0...];
		const epic_ps = fmt::bsprintf(epic_ps_buf, "Start-Process '{}'", epic_uri)!;
		append(epic_args, "powershell.exe")!;
		append(epic_args, "-NoProfile")!;
		append(epic_args, "-Command")!;
		append(epic_args, epic_ps)!;
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
		const proton_path = fmt::bsprintf(proton_buf, "{}/.local/share/hpo/zhen/proton/GE-Proton11-1", home)!;
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
			fmt::printfln("  Proton: GE-Proton11-1")!;
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

fn play_bell_async() void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "";
	};
	static let path_buf2: [512]u8 = [0...];
	const bell_path = fmt::bsprintf(path_buf2, "{}/.local/share/hpo/bell.mp3", home)!;
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
	exec::start(&cmd)!;
};

fn print_help() void = {
	fmt::println("hpo - The Hare Download & Game Manager v4.25.0")!;
	fmt::println("")!;
	fmt::println("USAGE:")!;
	fmt::println("  hpo <url|magnet|rooster> [options]    Download mode")!;
	fmt::println("  hpo --epic <action> <game>            Epic Games launcher")!;
	fmt::println("  hpo --steam <action|alias>            Steam launcher")!;
	fmt::println("  hpo --zhen-setup [--proton]           Install Zhen engine")!;
	fmt::println("  hpo oogway [seconds]                  Master Oogway meditation")!;
	fmt::println("  hpo roz vejr [city]                   Roz weather robot")!;
	fmt::println("  hpo shifu [city] [day]                Master Shifu cinema guide")!;
	fmt::println("  hpo chameleon <action> [game]         The Chameleon save manager")!;
	fmt::println("  hpo tailung <url1> <url2> ...         Tai Lung parallel download")!;
	fmt::println("  hpo tigress                           Tigress quote of the day")!;
	fmt::println("  hpo piyoko                            Piyoko wallet (Piyokocoin)")!;
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
	fmt::println("EPIC GAMES (legendary + Zhen on Linux, cmd.exe bridge on WSL):")!;
	fmt::println("  hpo --epic list                       List all Epic games")!;
	fmt::println("  hpo --epic install <app|alias>        Install a game")!;
	fmt::println("  hpo --epic launch <app|alias>         Launch a game")!;
	fmt::println("  Aliases: ~/.config/hpo/epic_aliases.txt")!;
	fmt::println("")!;
	fmt::println("STEAM / FOXFIRE (URI handler + Zhen on Linux, cmd.exe bridge on WSL):")!;
	fmt::println("  hpo --steam list                      List installed games")!;
	fmt::println("  hpo --steam install <appid|alias>     Install a game")!;
	fmt::println("  hpo --steam launch <appid|alias>      Launch a game")!;
	fmt::println("  hpo --steam wishlist <appid>          Open store (click to wishlist)")!;
	fmt::println("  hpo --steam page <appid>              Open Steam store page")!;
	fmt::println("  hpo --steam validate <appid|alias>    Verify game files")!;
	fmt::println("  hpo --steam <alias>                   Short syntax (auto-launch)")!;
	fmt::println("  hpo --steamfoxfire <args>             Same as --steam (Foxfire alias)")!;
	fmt::println("  Aliases: ~/.config/hpo/steam_aliases.txt")!;
	fmt::println("")!;
	fmt::println("ZHEN ENGINE (self-contained gaming runtime):")!;
	fmt::println("  hpo --setup                           Install EVERYTHING (apt+pip+zhen+steamcmd)")!;
	fmt::println("  hpo --zhen-setup                      Install umu-launcher")!;
	fmt::println("  hpo --zhen-setup --proton             Also install GE-Proton11-1")!;
	fmt::println("  hpo --zhen-update                     Check & install latest GE-Proton")!;
	fmt::println("  hpo zhen install <alias>              Install a Steam game via SteamCMD")!;
	fmt::println("  hpo zhen force <alias>                Set GE-Proton for a game (DRM-safe)")!;
	fmt::println("  hpo zhen force --all                  Set GE-Proton for ALL your games")!;
	fmt::println("  On WSL: bridges Steam/Epic to Windows via cmd.exe URI handlers")!;
	fmt::println("")!;
	fmt::println("OOGWAY MEDITATION (with monastery bell):")!;
	fmt::println("  hpo oogway                            10 min guided session")!;
	fmt::println("  hpo oogway 60                         Custom duration in seconds")!;
	fmt::println("  hpo oogway 300                        5 min mini session")!;
	fmt::println("  Bell sound: ~/.local/share/hpo/bell.mp3 (played via mpv)")!;
	fmt::println("")!;
	fmt::println("ROZ WEATHER ROBOT (The Wild Robot themed):")!;
	fmt::println("  hpo roz vejr                          Auto-locate via IP")!;
	fmt::println("  hpo roz vejr rødekro                  Specific city")!;
	fmt::println("  hpo roz vejr sydney                   Anywhere in the world")!;
	fmt::println("  Data: ip-api.com + Open-Meteo (no API key needed)")!;
	fmt::println("")!;
	fmt::println("SHIFU CINEMA GUIDE (live Danish cinema schedules):")!;
	fmt::println("  hpo shifu                             List nearby cinemas")!;
	fmt::println("  hpo shifu haderslev                   Today's program")!;
	fmt::println("  hpo shifu haderslev torsdag           Specific weekday")!;
	fmt::println("  hpo shifu haderslev weekend           Saturday + Sunday")!;
	fmt::println("  hpo shifu haderslev uge               Full week (7 days)")!;
	fmt::println("  hpo shifu haderslev imorgen           Tomorrow")!;
	fmt::println("  Days: mandag-søndag, idag, imorgen, weekend, uge")!;
	fmt::println("  Custom portrait: ~/.config/hpo/art/shifu.txt")!;
	fmt::println("  Data: bio.ebillet.dk (90+ Danish cinemas)")!;
	fmt::println("")!;
	fmt::println("CHAMELEON SAVE MANAGER (Kung Fu Panda 4 themed, WSL Steam saves):")!;
	fmt::println("  hpo chameleon backup <alias>          Steal (backup) a game's save")!;
	fmt::println("  hpo chameleon list                    Show all stolen saves")!;
	fmt::println("  hpo chameleon restore <alias>         Restore latest backup")!;
	fmt::println("  Saves stored in: ~/hpo-saves/")!;
	fmt::println("")!;
	fmt::println("EXTRAS (Rooster Fighter & Kung Fu Panda themed):")!;
	fmt::println("  hpo tailung <urls...>                 Download many files at once")!;
	fmt::println("  hpo tigress                           Daily motivational quote")!;
	fmt::println("  hpo piyoko                            Show Piyokocoin balance")!;
	fmt::println("  hpo piyoko spin                       Gamble 1 PYO (just for fun!)")!;
	fmt::println("  hpo piyoko cook                       Unlock a random recipe (5 PYO)")!;
	fmt::println("  hpo piyoko cookbook                   Show unlocked recipes")!;
	fmt::println("  hpo piyoko recipe <n>                 Fetch the real recipe online")!;
	fmt::println("  (earn 1 Piyokocoin per completed download!)")!;
	fmt::println("")!;
	fmt::println("EXAMPLES:")!;
	fmt::println("  hpo https://example.com/file.zip      Download a file")!;
	fmt::println("  hpo --epic launch celeste             Launch Celeste")!;
	fmt::println("  hpo --steam kao                       Launch Kao the Kangaroo")!;
	fmt::println("  hpo chameleon backup reanimal         Backup your REANIMAL save")!;
	fmt::println("  hpo oogway 300                        5 minutes of inner peace")!;
	fmt::println("  hpo roz vejr                          Should I bring a raincoat?")!;
	fmt::println("  hpo shifu haderslev weekend           What's playing this weekend?")!;
	fmt::println("")!;
	fmt::println("DOWNLOAD BACKENDS:")!;
	fmt::println("  HTTP/HTTPS/FTP  -> curl (dragon progress bar)")!;
	fmt::println("  Google Drive    -> gdown")!;
	fmt::println("  magnet:         -> aria2c")!;
	fmt::println("  rooster:        -> openssl (AES-256-CBC)")!;
	fmt::println("  Suno music      -> curl + ffmpeg (auto MP3 convert)")!;
	fmt::println("")!;
	fmt::println("CACHING:")!;
	fmt::println("  ~/.cache/hpo/location.json            IP location (7 days)")!;
	fmt::println("  ~/.cache/hpo/cinemas_*.json           Nearby cinemas (7 days)")!;
	fmt::println("  ~/.cache/hpo/events.json              All Danish showings (6 hours)")!;
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
	fmt::print("\x1b[2J\x1b[H")!;  // Clear screen + cursor home
	fmt::println("")!;
	fmt::println("                    \x1b[33m🐢  HPO OOGWAY  🐢\x1b[0m")!;
	fmt::println("")!;
	fmt::println("                  \x1b[36m┏━━━━━━━━━━━━━━━━━━━━━━┓\x1b[0m")!;
	fmt::println("                  \x1b[36m┃  Inner Peace Session  ┃\x1b[0m")!;
	fmt::println("                  \x1b[36m┗━━━━━━━━━━━━━━━━━━━━━━┛\x1b[0m")!;
	fmt::println("")!;

	// Start-bell: lille ding (non-blocking så Oogway vises straks)
	play_bell_async();
	time::sleep(500 * time::MILLISECOND);

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
fn weather_emoji(code: int) (str, str) = {
	// WMO Weather codes → emoji + besked
	switch (code) {
	case 0 =>
		return ("☀️", "Clear sky. Brightbill would fly today.");
	case 1 =>
		return ("🌤️", "Mainly clear. Soft winds across the island.");
	case 2 =>
		return ("⛅", "Partly cloudy. The trees whisper.");
	case 3 =>
		return ("☁️", "Overcast. The forest grows quiet.");
	case 45, 48 =>
		return ("🌫️", "Fog. Step carefully on the ground.");
	case 51, 53, 55 =>
		return ("🌦️", "Drizzle. A light coat would suffice.");
	case 56, 57 =>
		return ("🌨️", "Freezing drizzle. The bark turns crystal.");
	case 61, 63, 65 =>
		return ("🌧️", "Rain. Bring your rain jacket. Brightbill would not fly.");
	case 66, 67 =>
		return ("🌧️", "Freezing rain. Stay warm, my friend.");
	case 71, 73, 75 =>
		return ("🌨️", "Snow falls. The island grows white.");
	case 77 =>
		return ("🌨️", "Snow grains. Tiny ice from above.");
	case 80, 81, 82 =>
		return ("🌧️", "Rain showers. The clouds gather and release.");
	case 85, 86 =>
		return ("🌨️", "Snow showers. Drifts may form.");
	case 95 =>
		return ("⛈️", "Thunderstorm. Seek shelter beneath strong branches.");
	case 96, 99 =>
		return ("⛈️", "Severe thunderstorm with hail. Do not venture out.");
	case =>
		return ("🌍", "Conditions unknown. Trust your senses.");
	};
};

fn extract_array_value(json: str, key: str, idx: size) f64 = {
	// Find "key":[v1,v2,v3,...] og returner element ved idx
	static let pat_buf: [128]u8 = [0...];
	const pat = fmt::bsprintf(pat_buf, "\"{}\":[", key)!;
	const start_idx = match (strings::index(json, pat)) {
	case let n: size => yield n + len(pat);
	case void => return 0.0;
	};
	const array_str = strings::sub(json, start_idx, strings::end);
	const end_idx = match (strings::index(array_str, "]")) {
	case let n: size => yield n;
	case void => return 0.0;
	};
	const array_only = strings::sub(array_str, 0, end_idx);
	const parts = match (strings::split(array_only, ",")) {
	case let s: []str => yield s;
	case => return 0.0;
	};
	defer free(parts);
	if (idx >= len(parts)) return 0.0;
	const trimmed = strings::trim(parts[idx]);
	return match (strconv::stof64(trimmed)) {
	case let f: f64 => yield f;
	case => yield 0.0;
	};
};


fn parse_json_num(json: str, key: str) f64 = {
	// Simpel JSON-parser: find "key":<number>
	static let pat_buf: [128]u8 = [0...];
	const pat = fmt::bsprintf(pat_buf, "\"{}\":", key)!;
	const idx = match (strings::index(json, pat)) {
	case let n: size => yield n;
	case void => return 0.0;
	};
	const after = strings::sub(json, idx + len(pat), strings::end);
	const trimmed = strings::ltrim(after);
	// Læs tal indtil komma eller }
	const bytes = strings::toutf8(trimmed);
	let end = 0z;
	for (end < len(bytes); end += 1) {
		const c = bytes[end];
		if (c == ',': u8 || c == '}': u8 || c == ' ': u8) break;
	};
	const num_str = strings::sub(trimmed, 0, end);
	return match (strconv::stof64(num_str)) {
	case let f: f64 => yield f;
	case => yield 0.0;
	};
};

fn parse_json_str(json: str, key: str) str = {
	static let pat_buf: [128]u8 = [0...];
	const pat = fmt::bsprintf(pat_buf, "\"{}\":", key)!;
	const idx = match (strings::index(json, pat)) {
	case let n: size => yield n;
	case void => return "Unknown";
	};
	const after = strings::sub(json, idx + len(pat), strings::end);
	const trimmed = strings::ltrim(after);
	if (!strings::hasprefix(trimmed, "\"")) return "Unknown";
	const no_quote = strings::sub(trimmed, 1, strings::end);
	const end = match (strings::index(no_quote, "\"")) {
	case let n: size => yield n;
	case void => return "Unknown";
	};
	return strings::dup(strings::sub(no_quote, 0, end))!;
};

fn url_encode(s: str) str = {
	// Simpel URL-encoder for non-ASCII bytes
	const bytes = strings::toutf8(s);
	let result = strings::dup("")!;
	for (let i = 0z; i < len(bytes); i += 1) {
		const b = bytes[i];
		if ((b >= 'A': u8 && b <= 'Z': u8) || (b >= 'a': u8 && b <= 'z': u8) || (b >= '0': u8 && b <= '9': u8) || b == '-': u8 || b == '_': u8 || b == '.': u8 || b == '~': u8) {
			static let cbuf: [2]u8 = [0...];
			cbuf[0] = b;
			cbuf[1] = 0;
			const old = result;
			result = strings::concat(old, strings::fromutf8(cbuf[..1])!)!;
			free(old);
		} else {
			static let hex_buf: [8]u8 = [0...];
			const encoded = fmt::bsprintf(hex_buf, "%{:x}", b)!;
			const old = result;
			result = strings::concat(old, encoded)!;
			free(old);
		};
	};
	return result;
};

fn do_roz(o: *opts) void = {
	let _ = o;

	fmt::println("")!;
	fmt::println("              \x1b[36m🤖 [ROZZUM UNIT 7134] 🤖\x1b[0m")!;
	fmt::println("                 \x1b[33mWeather Analysis Mode\x1b[0m")!;
	fmt::println("")!;

	// Custom Roz portrait fra ~/.config/hpo/art/roz.txt
	const home_r = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let roz_path_buf: [512]u8 = [0...];
	const roz_path = fmt::bsprintf(roz_path_buf, "{}/.config/hpo/art/roz.txt", home_r)!;
	let drew_roz = false;
	match (os::open(roz_path)) {
	case let rf: io::file =>
		static let roz_buf: [16384]u8 = [0...];
		const rn = match (io::read(rf, roz_buf)) {
		case let nn: size => yield nn;
		case => yield 0z;
		};
		io::close(rf)!;
		if (rn > 0) {
			const roz_text = strings::fromutf8(roz_buf[..rn])!;
			if (!o.nocolor) fmt::print("\x1b[36m")!;
			fmt::print(roz_text)!;
			if (!o.nocolor) fmt::print("\x1b[0m")!;
			drew_roz = true;
		};
	case => void;
	};

	if (!drew_roz) {
		fmt::println("                    \x1b[37m┌──────────┐\x1b[0m")!;
		fmt::println("                    \x1b[37m│ \x1b[36m◉      ◉\x1b[37m │\x1b[0m")!;
		fmt::println("                    \x1b[37m│ ──────── │\x1b[0m")!;
		fmt::println("                    \x1b[37m│  \x1b[35m▮▮▮▮▮▮\x1b[37m  │\x1b[0m")!;
		fmt::println("                    \x1b[37m└────┬─────┘\x1b[0m")!;
		fmt::println("                         \x1b[37m│\x1b[0m")!;
		fmt::println("                    \x1b[37m┌────┴─────┐\x1b[0m")!;
		fmt::println("                    \x1b[37m│ ▮▮▮▮▮▮▮▮ │\x1b[0m")!;
		fmt::println("                    \x1b[37m└──┬────┬──┘\x1b[0m")!;
		fmt::println("                       \x1b[37m│    │\x1b[0m")!;
	};
	fmt::println("")!;

	cprint(C_CYAN, "ROZ", "Locating sensor position...", false);

	// Step 1: Få lat/lon/city - geocoding hvis by er givet, ellers IP
	let loc_args: []str = alloc([], 5)!;
	defer free(loc_args);
	append(loc_args, "curl")!;
	append(loc_args, "-s")!;
	append(loc_args, "--max-time")!;
	append(loc_args, "10")!;
	if (len(o.roz_city) > 0) {
		const encoded_city = url_encode(o.roz_city);
		defer free(encoded_city);
		static let geo_url_buf: [512]u8 = [0...];
		const geo_url = fmt::bsprintf(geo_url_buf, "https://geocoding-api.open-meteo.com/v1/search?name={}&count=1", encoded_city)!;
		append(loc_args, geo_url)!;
	} else {
		append(loc_args, "http://ip-api.com/json/")!;
	};

	const loc_cmd = match (exec::cmd("curl", loc_args[1..]...)) {
	case let c: exec::command => yield c;
	case =>
		cprint(C_RED, "ROZ", "Sensor offline. Cannot determine location.", false);
		return;
	};
	const loc_pipe = exec::pipe();
	exec::addfile(&loc_cmd, os::stdout_file, loc_pipe.1)!;
	const loc_proc = match (exec::start(&loc_cmd)) {
	case let p: exec::process => yield p;
	case =>
		cprint(C_RED, "ROZ", "Sensor initialization failed.", false);
		return;
	};
	io::close(loc_pipe.1)!;
	static let loc_buf: [4096]u8 = [0...];
	const loc_n = match (io::read(loc_pipe.0, loc_buf)) {
	case let nn: size => yield nn;
	case => yield 0z;
	};
	io::close(loc_pipe.0)!;
	exec::wait(&loc_proc)!;
	const loc_json = strings::fromutf8(loc_buf[..loc_n])!;

	let lat: f64 = 0.0;
	let lon: f64 = 0.0;
	let city: str = "";
	let country: str = "";
	if (len(o.roz_city) > 0) {
		// Open-Meteo geocoding API - skip forbi "results":[{ til selve resultatet
		const sliced = match (strings::index(loc_json, "\"results\":[{")) {
		case let idx: size => yield strings::sub(loc_json, idx, strings::end);
		case void => yield loc_json;
		};
		lat = parse_json_num(sliced, "latitude");
		lon = parse_json_num(sliced, "longitude");
		city = parse_json_str(sliced, "name");
		country = parse_json_str(sliced, "country");
	} else {
		// ip-api.com
		lat = parse_json_num(loc_json, "lat");
		lon = parse_json_num(loc_json, "lon");
		city = parse_json_str(loc_json, "city");
		country = parse_json_str(loc_json, "country");
	};

	cprint(C_CYAN, "ROZ", "Scanning sky conditions...", false);
	fmt::println("")!;

	let day_offset: int = 0;
	let use_forecast = false;
	if (o.roz_day == "imorgen" || o.roz_day == "tomorrow") { day_offset = 1; use_forecast = true; };
	if (o.roz_day == "mandag" || o.roz_day == "monday") { day_offset = -1; use_forecast = true; };
	if (o.roz_day == "tirsdag" || o.roz_day == "tuesday") { day_offset = -2; use_forecast = true; };
	if (o.roz_day == "onsdag" || o.roz_day == "wednesday") { day_offset = -3; use_forecast = true; };
	if (o.roz_day == "torsdag" || o.roz_day == "thursday") { day_offset = -4; use_forecast = true; };
	if (o.roz_day == "fredag" || o.roz_day == "friday") { day_offset = -5; use_forecast = true; };
	if (o.roz_day == "lørdag" || o.roz_day == "loerdag" || o.roz_day == "saturday") { day_offset = -6; use_forecast = true; };
	if (o.roz_day == "søndag" || o.roz_day == "soendag" || o.roz_day == "sunday") { day_offset = -7; use_forecast = true; };

	static let url_buf: [512]u8 = [0...];
	let url: str = "";
	if (use_forecast) {
		url = fmt::bsprintf(url_buf, "https://api.open-meteo.com/v1/forecast?latitude={}&longitude={}&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code&timezone=auto&forecast_days=7", lat, lon)!;
	} else {
		url = fmt::bsprintf(url_buf, "https://api.open-meteo.com/v1/forecast?latitude={}&longitude={}&current=temperature_2m,precipitation,weather_code&timezone=auto", lat, lon)!;
	};
	let args: []str = alloc([], 4)!;
	defer free(args);
	append(args, "curl")!;
	append(args, "-s")!;
	append(args, "--max-time")!;
	append(args, "10")!;
	append(args, url)!;

	const cmd = match (exec::cmd("curl", args[1..]...)) {
	case let c: exec::command => yield c;
	case =>
		cprint(C_RED, "ROZ", "Weather sensor unreachable.", false);
		return;
	};
	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case =>
		cprint(C_RED, "ROZ", "Weather sensor failed.", false);
		return;
	};
	io::close(pipe.1)!;
	static let json_buf: [4096]u8 = [0...];
	const n = match (io::read(pipe.0, json_buf)) {
	case let nn: size => yield nn;
	case => yield 0z;
	};
	io::close(pipe.0)!;
	exec::wait(&proc)!;
	const full_json = strings::fromutf8(json_buf[..n])!;

	if (use_forecast) {
		const daily = match (strings::index(full_json, "\"daily\":{")) {
		case let idx: size => yield strings::sub(full_json, idx, strings::end);
		case void => yield full_json;
		};
		let target_idx = 1z;
		if (day_offset == 1) {
			target_idx = 1z;
		} else if (day_offset < 0) {
			const want_wd = (-day_offset - 1): int;
			const now = time::now(time::clock::REALTIME);
			const today_wd = ((now.sec / 86400 + 4) % 7): int;
			let days_ahead = want_wd - today_wd;
			if (days_ahead < 0) days_ahead += 7;
			target_idx = days_ahead: size;
		};
		const tmax = extract_array_value(daily, "temperature_2m_max", target_idx);
		const tmin = extract_array_value(daily, "temperature_2m_min", target_idx);
		const prob = extract_array_value(daily, "precipitation_probability_max", target_idx);
		const code_d = extract_array_value(daily, "weather_code", target_idx): int;
		const we = weather_emoji(code_d);
		fmt::println("")!;
		fmt::printfln("  📍 \x1b[33mLocation:\x1b[0m      {}, {}", city, country)!;
		fmt::printfln("  📅 \x1b[33mForecast:\x1b[0m      {} day(s) ahead", target_idx)!;
		fmt::printfln("  🌡️  \x1b[33mHigh / Low:\x1b[0m    {}°C / {}°C", tmax, tmin)!;
		fmt::printfln("  {}  \x1b[33mConditions:\x1b[0m    {}", we.0, we.1)!;
		fmt::printfln("  ☔ \x1b[33mRain chance:\x1b[0m   {}%", prob)!;
		fmt::println("")!;
	} else {
		const json = match (strings::index(full_json, "\"current\":{")) {
		case let idx: size => yield strings::sub(full_json, idx, strings::end);
		case void => yield full_json;
		};
		const temp = parse_json_num(json, "temperature_2m");
		const precip = parse_json_num(json, "precipitation");
		const code_f = parse_json_num(json, "weather_code");
		const code = code_f: int;
		const we = weather_emoji(code);
		fmt::println("")!;
		fmt::printfln("  📍 \x1b[33mLocation:\x1b[0m      {}, {}", city, country)!;
		fmt::printfln("  🌡️  \x1b[33mTemperature:\x1b[0m   {}°C", temp)!;
		fmt::printfln("  {}  \x1b[33mConditions:\x1b[0m    {}", we.0, we.1)!;
		fmt::printfln("  💧 \x1b[33mPrecipitation:\x1b[0m {} mm", precip)!;
		fmt::println("")!;
	};
};
type cinema = struct {
	name: str,
	lat: f64,
	lon: f64,
	dist: f64,
};

// Babyloniansk sqrt - kun til distance beregning
fn babylon_sqrt(x: f64) f64 = {
	if (x <= 0.0) return 0.0;
	let g = x / 2.0;
	for (let i = 0; i < 20; i += 1) {
		g = (g + x / g) / 2.0;
	};
	return g;
};

// Distance i km (approksimation for ~55° N)
fn dist_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) f64 = {
	const dlat = (lat2 - lat1) * 111.0;
	const dlon = (lon2 - lon1) * 65.0;
	return babylon_sqrt(dlat*dlat + dlon*dlon);
};

fn do_xp(o: *opts) void = {
	const bal = piyoko_balance();
	if (!o.nocolor) fmt::print(C_YELLOW)!;
	fmt::println("")!;
	fmt::println("   \u2554\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2557")!;
	fmt::println("   \u2551  PIYOKO ARCADE  \u2551")!;
	fmt::println("   \u2551  INSERT COIN!!  \u2551")!;
	fmt::printfln("   \u2551  CREDITS: {} PYO \u2551", bal)!;
	fmt::println("   \u255a\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u255d")!;
	if (!o.nocolor) fmt::print(C_RESET)!;

	const romdir_buf: [512]u8 = [0...];
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	const romdir = fmt::bsprintf(romdir_buf, "{}/.local/share/hpo/arcade/roms", home)!;

	if (o.xp_action == "" || o.xp_action == "list") {
		cprint(C_GREEN, "ARCADE", "Available machines:", o.nocolor);
		const ls_args: []str = ["ls", romdir];
		let _ = run_cmd(ls_args, o.nocolor);
		fmt::println("")!;
		cprint(C_BLUE, "ARCADE", "Play: hpo xp <romname>  (costs 2 PYO)", o.nocolor);
		return;
	};

	if (bal < 2) {
		cprint(C_RED, "ARCADE", "INSUFFICIENT CREDITS! Need 2 PYO.", o.nocolor);
		cprint(C_YELLOW, "ARCADE", "Earn PYO by downloading: hpo <url>", o.nocolor);
		return;
	};

	piyoko_save(bal - 2);
	cprint(C_GREEN, "ARCADE", "*CLINK* CREDIT 1 - GAME START!", o.nocolor);
	// Multi-system: nes/snes/genesis/gb via MAME cores
	const systems: [](str, str, str) = [
		("nes", "nes", ".nes"),
		("snes", "snes", ".sfc"),
		("genesis", "genesis", ".md"),
		("gb", "gameboy", ".gb"),
		("psx", "duckstation", ".cue"),
	];
	for (let si = 0z; si < len(systems); si += 1) {
		if (o.xp_action == systems[si].0 && o.xp_rom != "") {
			const sysbuf: [512]u8 = [0...];
			const syspath = fmt::bsprintf(sysbuf, "{}/.local/share/hpo/arcade/{}/{}{}", home, systems[si].0, o.xp_rom, systems[si].2)!;
			fmt::printfln("   Booting {} [{}]... (2 PYO spent, {} left)", o.xp_rom, systems[si].0, bal - 2)!;
			if (systems[si].0 == "psx") {
				const home2 = match (os::getenv("HOME")) { case let s: str => yield s; case void => yield "/tmp"; };
				const dbuf: [512]u8 = [0...];
				const duck = fmt::bsprintf(dbuf, "{}/.local/share/hpo/duckstation.AppImage", home2)!;
				const psx_args: []str = [duck, syspath];
				let _ = run_cmd(psx_args, o.nocolor);
			} else if (systems[si].0 == "gb") {
				const gb_args: []str = ["mgba", syspath];
				let _ = run_cmd(gb_args, o.nocolor);
			} else {
				const con_args: []str = ["mame", systems[si].1, "-cart", syspath];
				let _ = run_cmd(con_args, o.nocolor);
			};
			return;
		};
	};
	fmt::printfln("   Booting {}... (2 PYO spent, {} left)", o.xp_action, bal - 2)!;
	const mame_args: []str = ["mame", "-rompath", romdir, o.xp_action];
	let _ = run_cmd(mame_args, o.nocolor);
};

fn do_bnet(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_BLUE)!;
	fmt::println("   [BNET] Opening the Dark Portal to Battle.net...")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	const home = match (os::getenv("HOME")) { case let x: str => yield x; case void => yield "/tmp"; };
	const pbuf: [512]u8 = [0...];
	const proton = fmt::bsprintf(pbuf, "{}/.local/share/hpo/zhen/proton/GE-Proton11-1", home)!;
	const ubuf: [512]u8 = [0...];
	const umu = fmt::bsprintf(ubuf, "{}/.local/share/hpo/zhen/umu-run", home)!;
	const prefbuf: [512]u8 = [0...];
	const prefix = fmt::bsprintf(prefbuf, "{}/.proton-prefix-bnet", home)!;
	const zbuf: [512]u8 = [0...];
	const zhen = fmt::bsprintf(zbuf, "{}/.local/share/hpo/zhen", home)!;
	os::setenv("WINEPREFIX", prefix)!;
	os::setenv("STEAM_COMPAT_DATA_PATH", prefix)!;
	os::setenv("STEAM_COMPAT_CLIENT_INSTALL_PATH", zhen)!;
	os::setenv("PROTONPATH", proton)!;
	os::setenv("GAMEID", "umu-0")!;
	os::setenv("STORE", "none")!;
	os::setenv("WINEDLLOVERRIDES", "locationapi=d")!;
	os::setenv("WINE_SIMULATE_WRITECOPY", "1")!;
	os::setenv("WINEFSYNC", "1")!;
	if (o.bnet_setup) {
		cprint(C_YELLOW, "BNET", "Installing Battle.net via Zhen (GE-Proton11-1)...", o.nocolor);
		const sbuf: [512]u8 = [0...];
		const setup = fmt::bsprintf(sbuf, "{}/.local/share/hpo/bnet/Battle.net-Setup.exe", home)!;
		const args: []str = [umu, setup];
		let _ = run_cmd(args, o.nocolor);
		cprint(C_GREEN, "BNET", "Setup done! Launch with: hpo bnet", o.nocolor);
		return;
	};
	cprint(C_GREEN, "BNET", "For the Horde! Launching Battle.net...", o.nocolor);
	const bbuf: [512]u8 = [0...];
	const bnetexe = fmt::bsprintf(bbuf, "{}/.proton-prefix-bnet/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe", home)!;
	const args: []str = [umu, bnetexe];
	let _ = run_cmd(args, o.nocolor);
};

fn do_doctor(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_BLUE)!;
	fmt::println("")!;
	fmt::println("   =====================================")!;
	fmt::println("    HPO DOCTOR - System Check")!;
	fmt::println("   =====================================")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	fmt::println("")!;
	cprint(C_YELLOW, "GPU", "Graphics", o.nocolor);
	fmt::printf("   nvidia-smi .... ")!;
	if (check_tool("nvidia-smi")) fmt::println("OK")! else fmt::println("MISSING")!;
	fmt::println("")!;
	cprint(C_YELLOW, "ZHEN", "Gaming engine", o.nocolor);
	fmt::printf("   umu-run ....... ")!;
	match (os::getenv("HOME")) { case let h: str => { const fp = fmt::asprintf("{}/.local/share/hpo/zhen/umu-run", h)!; defer free(fp); if (os::exists(fp)) fmt::println("OK")! else fmt::println("MISSING")!; }; case => fmt::println("?")!; };
	fmt::printf("   GE-Proton11-1 . ")!;
	match (os::getenv("HOME")) { case let h: str => { const fp = fmt::asprintf("{}/.local/share/hpo/zhen/proton/GE-Proton11-1", h)!; defer free(fp); if (os::exists(fp)) fmt::println("OK")! else fmt::println("MISSING")!; }; case => fmt::println("?")!; };
	fmt::printf("   SteamCMD ...... ")!;
	match (os::getenv("HOME")) { case let h: str => { const fp = fmt::asprintf("{}/.local/share/hpo/steamcmd/steamcmd.sh", h)!; defer free(fp); if (os::exists(fp)) fmt::println("OK")! else fmt::println("MISSING")!; }; case => fmt::println("?")!; };
	fmt::println("")!;
	cprint(C_YELLOW, "ARCADE", "Emulators (hpo xp)", o.nocolor);
	fmt::printf("   mame .......... ")!;
	if (check_tool("mame")) fmt::println("OK")! else fmt::println("MISSING")!;
	fmt::printf("   mgba .......... ")!;
	if (check_tool("mgba")) fmt::println("OK")! else fmt::println("MISSING")!;
	fmt::printf("   fceux ......... ")!;
	if (check_tool("fceux")) fmt::println("OK")! else fmt::println("MISSING")!;
	fmt::printf("   DuckStation ... ")!;
	match (os::getenv("HOME")) { case let h: str => { const fp = fmt::asprintf("{}/.local/share/hpo/duckstation.AppImage", h)!; defer free(fp); if (os::exists(fp)) fmt::println("OK")! else fmt::println("MISSING")!; }; case => fmt::println("?")!; };
	fmt::println("")!;
	cprint(C_YELLOW, "TOOLS", "Download tools", o.nocolor);
	fmt::printf("   curl .......... ")!;
	if (check_tool("curl")) fmt::println("OK")! else fmt::println("MISSING")!;
	fmt::printf("   aria2c ........ ")!;
	if (check_tool("aria2c")) fmt::println("OK")! else fmt::println("MISSING")!;
	fmt::println("")!;
	cprint(C_GREEN, "DOCTOR", "Any MISSING? Run: hpo --setup", o.nocolor);
	cprint(C_GREEN, "DOCTOR", "GPU mismatch on Flatpak Steam? Run: flatpak update -y", o.nocolor);
};

fn do_kai(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_GREEN)!;
	fmt::println("   [KAI] Take his chi! Jade-sharp anime with Anime4K...")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	if (o.kai_arg == "") {
		cprint(C_YELLOW, "KAI", "Usage: hpo kai <file> | <youtube-url> | <search words>", o.nocolor);
		return;
	};
	const home = match (os::getenv("HOME")) { case let x: str => yield x; case void => yield "/tmp"; };
	const sh = "~/.config/mpv/shaders/Anime4K_Clamp_Highlights.glsl:~/.config/mpv/shaders/Anime4K_Restore_CNN_M.glsl:~/.config/mpv/shaders/Anime4K_Thin_HQ.glsl:~/.config/mpv/shaders/Anime4K_Darken_HQ.glsl";
	const shaderarg = fmt::asprintf("--glsl-shaders={}", sh)!;
	defer free(shaderarg);
	let target = o.kai_arg;
	if (!strings::hasprefix(o.kai_arg, "http") && !strings::hasprefix(o.kai_arg, "/") && !strings::hasprefix(o.kai_arg, "~") && !strings::hasprefix(o.kai_arg, ".")) {
		cprint(C_GREEN, "KAI", "Searching YouTube for anime...", o.nocolor);
		target = fmt::asprintf("ytdl://ytsearch1:{}", o.kai_arg)!;
	};
	cprint(C_GREEN, "KAI", "Playing with Anime4K upscaling...", o.nocolor);
	const args: []str = ["mpv", shaderarg, "--ytdl-format=bestvideo+bestaudio/best", "--ytdl-raw-options=cookies-from-browser=brave", target];
	let _ = run_cmd(args, o.nocolor);
};

fn do_crane(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_CYAN)!;
	fmt::println("   [CRANE] Elegant and soaring - SoundCloud player!")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	if (o.crane_arg == "") {
		cprint(C_YELLOW, "CRANE", "Usage: hpo crane <url> | search | radio | yt | ytradio | web | local <path> | mix <path>", o.nocolor);
		return;
	};
	if (o.crane_arg == "search" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "Searching SoundCloud...", o.nocolor);
		const q = fmt::asprintf("ytdl://scsearch5:{}", o.crane_arg2)!;
		defer free(q);
		const args: []str = ["mpv", "--no-video", "--ytdl-raw-options=cookies-from-browser=brave", q];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	if (o.crane_arg == "yt" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "Searching YouTube...", o.nocolor);
		const q = fmt::asprintf("ytdl://ytsearch1:{}", o.crane_arg2)!;
		defer free(q);
		const args: []str = ["mpv", "--no-video", "--ytdl-raw-options=cookies-from-browser=brave", q];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	if (o.crane_arg == "radio" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "SoundCloud radio (10 tracks)...", o.nocolor);
		const q = fmt::asprintf("ytdl://scsearch10:{}", o.crane_arg2)!;
		defer free(q);
		const args: []str = ["mpv", "--no-video", "--ytdl-raw-options=cookies-from-browser=brave", q];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	if (o.crane_arg == "ytradio" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "YouTube radio (10 tracks)...", o.nocolor);
		const q = fmt::asprintf("ytdl://ytsearch10:{}", o.crane_arg2)!;
		defer free(q);
		const args: []str = ["mpv", "--no-video", "--ytdl-raw-options=cookies-from-browser=brave", q];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	if (o.crane_arg == "web" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "Opening SoundCloud search in browser...", o.nocolor);
		const url = fmt::asprintf("https://soundcloud.com/search?q={}", o.crane_arg2)!;
		defer free(url);
		const args: []str = ["xdg-open", url];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	if (o.crane_arg == "local" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "Playing local music (Suno, downloads)...", o.nocolor);
		const args: []str = ["mpv", "--no-video", o.crane_arg2];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	if (o.crane_arg == "mix" && o.crane_arg2 != "") {
		cprint(C_GREEN, "CRANE", "DJ mode! Shuffling your music...", o.nocolor);
		const args: []str = ["mpv", "--no-video", "--shuffle", "--loop-playlist", o.crane_arg2];
		let _ = run_cmd(args, o.nocolor);
		return;
	};
	cprint(C_GREEN, "CRANE", "Now playing...", o.nocolor);
	const args: []str = ["mpv", "--no-video", "--ytdl-raw-options=cookies-from-browser=brave", o.crane_arg];
	let _ = run_cmd(args, o.nocolor);
};

fn do_monkey(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_YELLOW)!;
	fmt::println("   [MONKEY] Acrobatic and fast - launching Rocket League!")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	const home = match (os::getenv("HOME")) { case let x: str => yield x; case void => yield "/tmp"; };
	const pbuf: [512]u8 = [0...];
	const proton = fmt::bsprintf(pbuf, "{}/.local/share/hpo/zhen/proton/GE-Proton11-1", home)!;
	if (o.monkey_setup) {
		cprint(C_YELLOW, "MONKEY", "Installing Rocket League via Epic (legendary)...", o.nocolor);
		const inst: []str = ["legendary", "install", "Sugar", "-y"];
		let _ = run_cmd(inst, o.nocolor);
		cprint(C_GREEN, "MONKEY", "Done! Launch with: hpo monkey", o.nocolor);
		return;
	};
	cprint(C_GREEN, "MONKEY", "GOAL! Booting Rocket League with GE-Proton11-1...", o.nocolor);
	const ubuf: [512]u8 = [0...];
	const umu = fmt::bsprintf(ubuf, "{}/.local/share/hpo/zhen/umu-run", home)!;
	os::setenv("PROTONPATH", proton)!;
	os::setenv("GAMEID", "umu-0")!;
	os::setenv("STORE", "egs")!;
	const args: []str = ["legendary", "launch", "Sugar", "--no-wine", "--wrapper", umu];
	let _ = run_cmd(args, o.nocolor);
};

fn do_viper(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_GREEN)!;
	fmt::println("   [VIPER] Swift and graceful - PlayStation Remote Play!")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	if (o.viper_setup) {
		cprint(C_YELLOW, "VIPER", "Installing chiaki-ng (PS4/PS5 Remote Play)...", o.nocolor);
		const inst: []str = ["flatpak", "install", "-y", "flathub", "io.github.streetpea.Chiaki4deck"];
		let _ = run_cmd(inst, o.nocolor);
		cprint(C_BLUE, "VIPER", "Need your PSN Account ID? Run the psn-account-id script.", o.nocolor);
		cprint(C_BLUE, "VIPER", "On PS5: Settings > System > Remote Play > Link Device for the PIN.", o.nocolor);
		cprint(C_GREEN, "VIPER", "Setup done! Launch with: hpo viper", o.nocolor);
		return;
	};
	cprint(C_GREEN, "VIPER", "Striking into the stream...", o.nocolor);
	const args: []str = ["flatpak", "run", "io.github.streetpea.Chiaki4deck"];
	let _ = run_cmd(args, o.nocolor);
};

fn do_mantis(o: *opts) void = {
	const home = match (os::getenv("HOME")) { case let x: str => yield x; case void => yield "/tmp"; };
	if (!o.nocolor) fmt::print(C_GREEN)!;
	fmt::println("")!;
	fmt::println("   \u2554\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2557")!;
	fmt::println("   \u2551  MANTIS - Manga Cart Hub  \u2551")!;
	fmt::println("   \u255a\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u255d")!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	fmt::println("   1  Sakamoto Days    (mestmanga.dk)")!;
	fmt::println("   2  Ichi the Witch   (mestmanga.dk)")!;
	fmt::println("   3  Nue\x27s Exorcist   (williamdam.dk)")!;
	fmt::println("   q  Afslut")!;
	fmt::print("   Vaelg: ")!;
	bufio::flush(os::stdout)!;
	const line = match (bufio::read_line(os::stdin)) {
		case let b: []u8 => yield strings::fromutf8(b)!;
		case => return;
	};
	const choice = strings::trim(line);
	let dir = "";
	let bin = "";
	if (choice == "1") { dir = "sakamoto"; bin = "sakamoto_cart"; }
	else if (choice == "2") { dir = "Ichi"; bin = "ichi_cart"; }
	else if (choice == "3") { dir = "williamdam_cart"; bin = "build/a.out"; }
	else { cprint(C_YELLOW, "MANTIS", "Afslutter.", o.nocolor); return; };
	if (!o.nocolor) fmt::print(C_GREEN)!;
	fmt::printfln("   [MANTIS] Swift and precise! Opening {}...", dir)!;
	if (!o.nocolor) fmt::print(C_RESET)!;
	const cbuf: [1024]u8 = [0...];
	const cmd = fmt::bsprintf(cbuf, "cd {}/Documents/{} && ./{}", home, dir, bin)!;
	const args: []str = ["sh", "-c", cmd];
	let _ = run_cmd(args, o.nocolor);
};

fn do_ping(o: *opts) void = {
	if (!o.nocolor) fmt::print(C_YELLOW)!;
	fmt::println("   [PING] Mr. Ping fyrer op for nudelgryden... og Roblox!")!;
	if (!o.nocolor) fmt::print(C_RESET)!;

	if (o.ping_setup) {
		cprint(C_YELLOW, "PING", "Installing Sober (Roblox) via Flatpak...", o.nocolor);
		let a: []str = alloc([], 6)!;
		defer free(a);
		append(a, "flatpak")!;
		append(a, "install")!;
		append(a, "-y")!;
		append(a, "flathub")!;
		append(a, "org.vinegarhq.Sober")!;
		let _ = run_cmd(a, o.nocolor);
		cprint(C_GREEN, "PING", "Sober installed! Run: hpo ping", o.nocolor);
		return;
	};

	cprint(C_GREEN, "PING", "Serving up Roblox! Skadoosh!", o.nocolor);
	let a: []str = alloc([], 4)!;
	defer free(a);
	append(a, "flatpak")!;
	append(a, "run")!;
	append(a, "org.vinegarhq.Sober")!;
	let _ = run_cmd(a, o.nocolor);
};

fn do_shifu(o: *opts) void = {
	fmt::println("")!;
	fmt::println("              \x1b[33m🐭  [MASTER SHIFU]  🐭\x1b[0m")!;
	fmt::println("                 \x1b[36mCinema Guidance Mode\x1b[0m")!;
	fmt::println("")!;

	// Custom ASCII art fra ~/.config/hpo/art/shifu.txt (Bossun's egen tegning)
	const home_s = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let art_path_buf: [512]u8 = [0...];
	const art_path = fmt::bsprintf(art_path_buf, "{}/.config/hpo/art/shifu.txt", home_s)!;
	let drew_art = false;
	match (os::open(art_path)) {
	case let af: io::file =>
		static let art_buf: [8192]u8 = [0...];
		const an = match (io::read(af, art_buf)) {
		case let nn: size => yield nn;
		case => yield 0z;
		};
		io::close(af)!;
		if (an > 0) {
			const art_text = strings::fromutf8(art_buf[..an])!;
			if (!o.nocolor) fmt::print("\x1b[35m")!;
			fmt::print(art_text)!;
			if (!o.nocolor) fmt::print("\x1b[0m")!;
			drew_art = true;
		};
	case => void;
	};

	// Fallback: simpel ASCII hvis ingen art-fil
	if (!drew_art) {
		fmt::println("                       \x1b[35m    .--.\x1b[0m")!;
		fmt::println("                       \x1b[35m   ( oo )\x1b[0m")!;
		fmt::println("                       \x1b[35m    \\__/\x1b[0m")!;
		fmt::println("                       \x1b[35m    /  \\\x1b[0m")!;
		fmt::println("                       \x1b[35m   <    >\x1b[0m")!;
		fmt::println("                       \x1b[35m    \\__/\x1b[0m")!;
	};
	fmt::println("")!;

	// Step 1: lat/lon - by-override eller IP
	let user_lat: f64 = 0.0;
	let user_lon: f64 = 0.0;
	let user_city: str = "";

	// Tjek cache for IP-location (kun hvis ingen city-override)
	const home_x = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let cache_dir_buf: [512]u8 = [0...];
	const cache_dir = fmt::bsprintf(cache_dir_buf, "{}/.cache/hpo", home_x)!;
	os::mkdir(cache_dir, 0o755): void;
	static let loc_cache_buf: [512]u8 = [0...];
	const loc_cache_path = fmt::bsprintf(loc_cache_buf, "{}/location.json", cache_dir)!;

	let use_cache = false;
	if (len(o.shifu_city) == 0 && os::exists(loc_cache_path)) {
		// Tjek alder på cache via stat
		match (os::stat(loc_cache_path)) {
		case let st: fs::filestat =>
			const now = time::now(time::clock::REALTIME);
			const age_sec = now.sec - st.mtime.sec;
			if (age_sec < 604800) { // 7 dage
				use_cache = true;
			};
		case => void;
		};
	};

	let loc_args: []str = alloc([], 5)!;
	defer free(loc_args);
	append(loc_args, "curl")!;
	append(loc_args, "-s")!;
	append(loc_args, "--max-time")!;
	append(loc_args, "10")!;
	if (len(o.shifu_city) > 0) {
		const encoded = url_encode(o.shifu_city);
		defer free(encoded);
		static let geo_url_buf: [512]u8 = [0...];
		const geo_url = fmt::bsprintf(geo_url_buf, "https://geocoding-api.open-meteo.com/v1/search?name={}&count=1", encoded)!;
		append(loc_args, geo_url)!;
	} else {
		append(loc_args, "http://ip-api.com/json/")!;
	};

	const loc_cmd = match (exec::cmd("curl", loc_args[1..]...)) {
	case let c: exec::command => yield c;
	case =>
		cprint(C_RED, "SHIFU", "Cannot locate sensor position.", false);
		return;
	};
	let loc_json: str = "";
	static let loc_buf: [4096]u8 = [0...];

	if (use_cache) {
		cprint(C_CYAN, "SHIFU", "Using cached location...", false);
		const cf = os::open(loc_cache_path)!;
		defer io::close(cf)!;
		const cn = match (io::read(cf, loc_buf)) {
		case let nn: size => yield nn;
		case => yield 0z;
		};
		loc_json = strings::fromutf8(loc_buf[..cn])!;
	} else {
		const loc_pipe = exec::pipe();
		exec::addfile(&loc_cmd, os::stdout_file, loc_pipe.1)!;
		const loc_proc = match (exec::start(&loc_cmd)) {
		case let p: exec::process => yield p;
		case => return;
		};
		io::close(loc_pipe.1)!;
		const loc_n = match (io::read(loc_pipe.0, loc_buf)) {
		case let nn: size => yield nn;
		case => yield 0z;
		};
		io::close(loc_pipe.0)!;
		exec::wait(&loc_proc)!;
		loc_json = strings::fromutf8(loc_buf[..loc_n])!;

		// Gem til cache (kun hvis IP-lookup)
		if (len(o.shifu_city) == 0) {
			match (os::create(loc_cache_path, 0o644)) {
			case let wf: io::file =>
				io::writeall(wf, strings::toutf8(loc_json))!;
				io::close(wf)!;
			case => void;
			};
		};
	};

	if (len(o.shifu_city) > 0) {
		const sliced = match (strings::index(loc_json, "\"results\":[{")) {
		case let idx: size => yield strings::sub(loc_json, idx, strings::end);
		case void => yield loc_json;
		};
		user_lat = parse_json_num(sliced, "latitude");
		user_lon = parse_json_num(sliced, "longitude");
		user_city = parse_json_str(sliced, "name");
	} else {
		user_lat = parse_json_num(loc_json, "lat");
		user_lon = parse_json_num(loc_json, "lon");
		user_city = parse_json_str(loc_json, "city");
	};

	// Først: forsøg Python helper for live cinema data
	if (len(o.shifu_city) > 0) {
		const helper_paths_early = [
			"/usr/local/share/hpo/shifu-events.py",
			"./helpers/shifu-events.py",
		]: []str;
		let helper_found_early: str = "";
		for (let hi = 0z; hi < len(helper_paths_early); hi += 1) {
			if (os::exists(helper_paths_early[hi])) {
				helper_found_early = helper_paths_early[hi];
				break;
			};
		};
		if (len(helper_found_early) > 0) {
			cprint(C_GREEN, "SHIFU", "Fetching program from ebillet.dk...", false);
			fmt::println("")!;
			// Split shifu_city på space og send som separate args
			const parts = match (strings::split(o.shifu_city, " ")) {
			case let p: []str => yield p;
			case => yield []: []str;
			};
			defer free(parts);
			let py_args: []str = alloc([], 10)!;
			defer free(py_args);
			append(py_args, "python3")!;
			append(py_args, helper_found_early)!;
			for (let pi = 0z; pi < len(parts); pi += 1) {
				if (len(parts[pi]) > 0) {
					append(py_args, parts[pi])!;
				};
			};
			const py_ok = run_cmd(py_args, false);
			fmt::println("")!;
			if (py_ok) return; // Skip resten hvis Python viste events
		};
	};

	// Tjek om shifu_city matcher en biograf i ~/.config/hpo/cinemas.json
	if (len(o.shifu_city) > 0) {
		const home_c = match (os::getenv("HOME")) {
		case let s: str => yield s;
		case void => yield "/tmp";
		};
		static let cpath_buf: [512]u8 = [0...];
		const cpath = fmt::bsprintf(cpath_buf, "{}/.config/hpo/cinemas.json", home_c)!;
		match (os::open(cpath)) {
		case let cf: io::file =>
			static let cjbuf: [16384]u8 = [0...];
			const cjn = match (io::read(cf, cjbuf)) {
			case let nn: size => yield nn;
			case => yield 0z;
			};
			io::close(cf)!;
			const cjson = strings::fromutf8(cjbuf[..cjn])!;
			// Match: find om shifu_city findes i JSON (case-sensitive)
			match (strings::index(cjson, o.shifu_city)) {
			case let qidx: size =>
				// Fundet match - find nærmeste "today_url" eller "url" efter dette punkt
				const after = strings::sub(cjson, qidx, strings::end);
				let target_url: str = "";
				match (strings::index(after, "\"today_url\":")) {
				case let tidx: size =>
					target_url = parse_json_str(strings::sub(after, tidx, strings::end), "today_url");
				case void => void;
				};
				if (target_url == "" || target_url == "Unknown") {
					match (strings::index(after, "\"url\":")) {
					case let uidx: size =>
						target_url = parse_json_str(strings::sub(after, uidx, strings::end), "url");
					case void => void;
					};
				};
				// Først: forsøg at vise dagens program via Python helper
				const helper_paths = [
					"/usr/local/share/hpo/shifu-events.py",
					"./helpers/shifu-events.py",
				]: []str;
				let helper_found: str = "";
				for (let hi = 0z; hi < len(helper_paths); hi += 1) {
					if (os::exists(helper_paths[hi])) {
						helper_found = helper_paths[hi];
						break;
					};
				};
				let py_success = false;
				if (len(helper_found) > 0) {
					cprint(C_GREEN, "SHIFU", "Fetching today's program...", false);
					fmt::println("")!;
					let py_args: []str = alloc([], 3)!;
					defer free(py_args);
					append(py_args, "python3")!;
					append(py_args, helper_found)!;
					append(py_args, o.shifu_city)!;
					py_success = run_cmd(py_args, false);
					fmt::println("")!;
				};
				if (py_success) return; // Skip browser hvis events vist

				if (len(target_url) > 0 && target_url != "Unknown") {
					cprint(C_GREEN, "SHIFU", "Opening cinema website in browser...", false);
					fmt::printfln("        \x1b[33m{}\x1b[0m", target_url)!;
					fmt::println("")!;
					let xdg_args: []str = alloc([], 2)!;
					defer free(xdg_args);
					append(xdg_args, "xdg-open")!;
					append(xdg_args, target_url)!;
					let _ = run_cmd(xdg_args, false);
					return;
				};
			case void => void;
			};
		case => void;
		};
	};

	fmt::printfln("\x1b[36m[SHIFU]\x1b[0m Searching cinemas near \x1b[33m{}\x1b[0m...", user_city)!;
	fmt::println("")!;

	// Tjek cinemas-cache (key: lat+lon, gælder 7 dage)
	static let cin_cache_buf: [512]u8 = [0...];
	const cin_cache_path = fmt::bsprintf(cin_cache_buf, "{}/cinemas_{}_{}.json", cache_dir, user_lat: int, user_lon: int)!;

	let use_cin_cache = false;
	if (os::exists(cin_cache_path)) {
		match (os::stat(cin_cache_path)) {
		case let st: fs::filestat =>
			const now = time::now(time::clock::REALTIME);
			const age_sec = now.sec - st.mtime.sec;
			if (age_sec < 604800) {
				use_cin_cache = true;
			};
		case => void;
		};
	};

	// Step 2: Overpass query
	static let q_buf: [512]u8 = [0...];
	const q = fmt::bsprintf(q_buf, "[out:json];nwr[amenity=cinema](around:50000,{},{});out center;", user_lat, user_lon)!;
	const q_enc = url_encode(q);
	defer free(q_enc);
	static let url_buf: [1024]u8 = [0...];
	const url = fmt::bsprintf(url_buf, "https://overpass-api.de/api/interpreter?data={}", q_enc)!;

	let args: []str = alloc([], 8)!;
	defer free(args);
	append(args, "curl")!;
	append(args, "-s")!;
	append(args, "--max-time")!;
	append(args, "20")!;
	append(args, "-H")!;
	append(args, "User-Agent: hpo-shifu/1.0")!;
	append(args, "-H")!;
	append(args, "Accept: application/json")!;
	append(args, url)!;

	static let resp_buf: [65536]u8 = [0...];
	let total: size = 0;
	if (use_cin_cache) {
		cprint(C_CYAN, "SHIFU", "Using cached cinema data...", false);
		const cf = os::open(cin_cache_path)!;
		defer io::close(cf)!;
		for (true) {
			const n = match (io::read(cf, resp_buf[total..])) {
			case let nn: size => yield nn;
			case io::EOF => break;
			case => break;
			};
			if (n == 0) break;
			total += n;
			if (total >= len(resp_buf)) break;
		};
	} else {
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
		for (true) {
			const n = match (io::read(pipe.0, resp_buf[total..])) {
			case let nn: size => yield nn;
			case io::EOF => break;
			case => break;
			};
			if (n == 0) break;
			total += n;
			if (total >= len(resp_buf)) break;
		};
		io::close(pipe.0)!;
		exec::wait(&proc)!;

		// Gem til cache
		match (os::create(cin_cache_path, 0o644)) {
		case let wf: io::file =>
			io::writeall(wf, resp_buf[..total])!;
			io::close(wf)!;
		case => void;
		};
	};

	const resp = strings::fromutf8(resp_buf[..total])!;

	// Parse cinemas: find alle "name":"..." blokke og deres lat/lon
	let cinemas: []cinema = alloc([], 30)!;
	defer free(cinemas);

	// Split på "tags":{ for at finde hver cinema's tag-blok
	let pos = 0z;
	for (true) {
		const rest = strings::sub(resp, pos, strings::end);
		// Find næste cinema: kig efter "amenity":"cinema"
		const tag_idx = match (strings::index(rest, "\"amenity\":")) {
		case let n: size => yield n;
		case void => break;
		};
		// Søg tilbage til seneste {"type" - for at få lat/lon før tags
		const before = strings::sub(rest, 0, tag_idx);
		const type_idx = match (strings::rindex(before, "\"type\":")) {
		case let n: size => yield n;
		case void => yield 0z;
		};
		const elem = strings::sub(rest, type_idx, strings::end);

		// Find slutningen af denne element (næste "type": eller end)
		const rest_after = strings::sub(elem, 50, strings::end);
		const next_type = match (strings::index(rest_after, "\"type\":")) {
		case let n: size => yield n + 50;
		case void => yield len(elem);
		};
		const block = strings::sub(elem, 0, next_type);

		const name = parse_json_str(block, "name");
		const c_lat = parse_json_num(block, "lat");
		const c_lon = parse_json_num(block, "lon");

		if (name != "Unknown" && c_lat > 1.0 && c_lon > 1.0) {
			const d = dist_km(user_lat, user_lon, c_lat, c_lon);
			append(cinemas, cinema {
				name = name,
				lat = c_lat,
				lon = c_lon,
				dist = d,
			})!;
		};
		pos = pos + tag_idx + 30;
	};

	// Sort by distance (simpel bubble sort)
	for (let i = 0z; i < len(cinemas); i += 1) {
		for (let j = 0z; j < len(cinemas) - 1; j += 1) {
			if (cinemas[j].dist > cinemas[j+1].dist) {
				const tmp = cinemas[j];
				cinemas[j] = cinemas[j+1];
				cinemas[j+1] = tmp;
			};
		};
	};

	cprint(C_GREEN, "SHIFU", "These cinemas are within walking or driving distance:", false);
	fmt::println("")!;

	const max_show = if (len(cinemas) > 8z) 8z else len(cinemas);
	for (let i = 0z; i < max_show; i += 1) {
		fmt::printfln("  🎬 \x1b[33m{}\x1b[0m", cinemas[i].name)!;
		fmt::printfln("     \x1b[36m~{} km away\x1b[0m", cinemas[i].dist: int)!;
	};

	fmt::println("")!;
	cprint(C_YELLOW, "SHIFU", "Choose wisely. Time is precious.", false);
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
		do_full_setup = false,
		zhen_install = false,
		zhen_force = false,
			ping = false,
			mantis = false,
			viper = false,
			viper_setup = false,
			monkey = false,
			monkey_setup = false,
			crane = false,
			crane_arg = "",
			crane_arg2 = "",
			kai = false,
			kai_arg = "",
			doctor = false,
			ping_setup = false,
			bnet = false,
			bnet_setup = false,
			xp = false,
			xp_action = "",
			xp_rom = "",
		zhen_force_target = "",
		zhen_install_target = "",
		zhen_update = false,
		zhen_proton = false,
		oogway = false,
		oogway_sec = 600u,
		roz = false,
		roz_city = "",
		roz_day = "",
		shifu = false,
		shifu_city = "",
		chameleon = false,
		chameleon_action = "",
		chameleon_target = "",
		chameleon_epic = false,
		tigress = false,
		piyoko = false,
		piyoko_action = "",
		piyoko_target = "",
		tailung = false,
		tailung_urls = [],
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
                } else if (a == "--steam" || a == "--steamfoxfire") {
                        i += 1;
                        if (i >= len(args)) {
                                fmt::errorfln("Error: --steam requires launch|list|install")!;
                                os::exit(1);
                        };
                        o.steam = true;
                        o.steam_cmd = args[i];
                } else if (a == "--zhen-update") {
                        o.zhen_update = true;
                } else if (a == "--setup") {
                        o.do_full_setup = true;
                } else if (a == "--zhen-setup") {
                        o.zhen_setup = true;
                } else if (a == "--proton") {
                        o.zhen_proton = true;
                } else if (a == "zhen") {
                        if (i + 1 < len(args) && args[i + 1] == "install") {
                                o.zhen_install = true;
                                i += 1;
                                if (i + 1 < len(args)) {
                                        o.zhen_install_target = args[i + 1];
                                        i += 1;
                                };
                        } else if (i + 1 < len(args) && args[i + 1] == "force") {
                                o.zhen_force = true;
                                i += 1;
                                if (i + 1 < len(args)) {
                                        o.zhen_force_target = args[i + 1];
                                        i += 1;
                                };
                        };
                } else if (a == "xp") {
                	o.xp = true;
                	if (i + 1 < len(args)) {
                		o.xp_action = args[i + 1];
                		i += 1;
                	};
                	if (i + 1 < len(args)) {
                		o.xp_rom = args[i + 1];
                		i += 1;
                	};
                } else if (a == "bnet") {
                	o.bnet = true;
                	if (i + 1 < len(args) && args[i + 1] == "setup") {
                		o.bnet_setup = true;
                		i += 1;
                	};
                } else if (a == "doctor") {
                	o.doctor = true;
                } else if (a == "kai") {
                	o.kai = true;
                	if (i + 1 < len(args)) {
                		o.kai_arg = args[i + 1];
                		i += 1;
                	};
                } else if (a == "crane") {
                	o.crane = true;
                	if (i + 1 < len(args)) {
                		o.crane_arg = args[i + 1];
                		i += 1;
                	};
                	if (i + 1 < len(args)) {
                		o.crane_arg2 = args[i + 1];
                		i += 1;
                	};
                } else if (a == "monkey") {
                	o.monkey = true;
                	if (i + 1 < len(args) && args[i + 1] == "setup") {
                		o.monkey_setup = true;
                		i += 1;
                	};
                } else if (a == "viper") {
                	o.viper = true;
                	if (i + 1 < len(args) && args[i + 1] == "setup") {
                		o.viper_setup = true;
                		i += 1;
                	};
                } else if (a == "mantis") {
                	o.mantis = true;
                } else if (a == "ping") {
                	o.ping = true;
                	if (i + 1 < len(args) && args[i + 1] == "setup") {
                		o.ping_setup = true;
                		i += 1;
                	};
                } else if (a == "shifu") {
                        o.shifu = true;
                        // Slurp alle remaining args som "city + day" combined
                        let combined = strings::dup("")!;
                        for (let k = i + 1; k < len(args); k += 1) {
                                if (len(combined) > 0) {
                                        const old_c = combined;
                                        combined = strings::concat(old_c, " ")!;
                                        free(old_c);
                                };
                                const old_c2 = combined;
                                combined = strings::concat(old_c2, args[k])!;
                                free(old_c2);
                        };
                        o.shifu_city = combined;
                        i = len(args); // skip resten af args
                } else if (a == "roz") {
                        o.roz = true;
                        // Tjek næste arg for "vejr"/"weather"
                        if (i + 1 < len(args)) {
                                const next = args[i + 1];
                                if (next == "vejr" || next == "weather" || next == "-w") {
                                        i += 1;
                                };
                        };
                        // Slurp remaining args. Sidste arg kan være dag-keyword.
                        let collected: []str = alloc([], 5)!;
                        defer free(collected);
                        for (let k = i + 1; k < len(args); k += 1) {
                                append(collected, args[k])!;
                        };
                        if (len(collected) > 0) {
                                const last = collected[len(collected) - 1];
                                if (last == "idag" || last == "today" || last == "nu" ||
                                    last == "imorgen" || last == "tomorrow" ||
                                    last == "mandag" || last == "monday" ||
                                    last == "tirsdag" || last == "tuesday" ||
                                    last == "onsdag" || last == "wednesday" ||
                                    last == "torsdag" || last == "thursday" ||
                                    last == "fredag" || last == "friday" ||
                                    last == "lørdag" || last == "loerdag" || last == "saturday" ||
                                    last == "søndag" || last == "soendag" || last == "sunday" ||
                                    last == "weekend" || last == "uge" || last == "week") {
                                        o.roz_day = last;
                                        // Resterende er city
                                        let city = strings::dup("")!;
                                        for (let k = 0z; k < len(collected) - 1; k += 1) {
                                                if (len(city) > 0) {
                                                        const old_c = city;
                                                        city = strings::concat(old_c, " ")!;
                                                        free(old_c);
                                                };
                                                const old_c2 = city;
                                                city = strings::concat(old_c2, collected[k])!;
                                                free(old_c2);
                                        };
                                        o.roz_city = city;
                                } else {
                                        // Ingen dag, alt er city
                                        let city = strings::dup("")!;
                                        for (let k = 0z; k < len(collected); k += 1) {
                                                if (len(city) > 0) {
                                                        const old_c = city;
                                                        city = strings::concat(old_c, " ")!;
                                                        free(old_c);
                                                };
                                                const old_c2 = city;
                                                city = strings::concat(old_c2, collected[k])!;
                                                free(old_c2);
                                        };
                                        o.roz_city = city;
                                };
                        };
                        i = len(args);
                } else if (a == "tailung") {
                	o.tailung = true;
                	for (i + 1 < len(args)) {
                		append(o.tailung_urls, args[i + 1])!;
                		i += 1;
                	};
                } else if (a == "piyoko") {
                	o.piyoko = true;
                	if (i + 1 < len(args)) {
                		o.piyoko_action = args[i + 1];
                		i += 1;
                	};
                	if (i + 1 < len(args)) {
                		o.piyoko_target = args[i + 1];
                		i += 1;
                	};
                } else if (a == "tigress") {
                	o.tigress = true;
                } else if (a == "chameleon") {
			for (i + 1 < len(args)) {
				const nxt = args[i + 1];
				if (nxt == "--epic") {
					o.chameleon_epic = true;
					i += 1;
				} else if (len(o.chameleon_action) == 0) {
					o.chameleon_action = nxt;
					i += 1;
				} else if (len(o.chameleon_target) == 0) {
					o.chameleon_target = nxt;
					i += 1;
				} else {
					break;
				};
			};
			o.chameleon = true;
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
	if (o.tailung) {
		do_tailung(o.tailung_urls, o.nocolor);
		return;
	};
	if (o.piyoko) {
		if (o.piyoko_action == "spin") {
			do_piyoko_spin(o.nocolor);
		} else if (o.piyoko_action == "cook") {
			do_piyoko_cook(o.nocolor);
		} else if (o.piyoko_action == "cookbook") {
			do_piyoko_cookbook(o.nocolor);
		} else if (o.piyoko_action == "recipe") {
			do_piyoko_recipe(o.piyoko_target, o.nocolor);
		} else {
			do_piyoko(o.nocolor);
		};
		return;
	};
	if (o.tigress) {
		do_tigress(o.nocolor);
		return;
	};
	if (o.chameleon) {
		if (o.chameleon_epic) {
			do_chameleon_epic(o.chameleon_action, o.chameleon_target, o.nocolor);
		} else {
			do_chameleon(o.chameleon_action, o.chameleon_target, o.nocolor);
		};
		return;
	};
	if (o.oogway) {
		do_oogway(&o);
		return;
	};
	if (o.roz) {
		do_roz(&o);
		return;
	};
	if (o.xp) {
		do_xp(&o);
		return;
	};
	if (o.bnet) {
		do_bnet(&o);
		return;
	};
	if (o.doctor) {
		do_doctor(&o);
		return;
	};
	if (o.kai) {
		do_kai(&o);
		return;
	};
	if (o.crane) {
		do_crane(&o);
		return;
	};
	if (o.monkey) {
		do_monkey(&o);
		return;
	};
	if (o.viper) {
		do_viper(&o);
		return;
	};
	if (o.mantis) {
		do_mantis(&o);
		return;
	};
	if (o.ping) {
		do_ping(&o);
		return;
	};
	if (o.shifu) {
		do_shifu(&o);
		return;
	};
	if (o.zhen_update) {
		do_zhen_update(&o);
		return;
	};
	if (o.do_full_setup) {
		do_setup(&o);
		return;
	};
	if (o.zhen_setup) {
		do_zhen_setup(&o);
		return;
	};
	if (o.zhen_force) {
		do_zhen_force(o.zhen_force_target, o.nocolor);
		return;
	};
	if (o.zhen_install) {
		do_zhen_install(o.zhen_install_target, o.nocolor);
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
