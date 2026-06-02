use fmt;
use io;
use os;
use os::exec;
use strings;
use time;
use fs;

fn chameleon_resolve_appid(target: str) str = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let abuf: [512]u8 = [0...];
	const apath = fmt::bsprintf(abuf, "{}/.config/hpo/steam_aliases.txt", home)!;
	match (os::open(apath)) {
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
				return strings::dup(strings::trim(parts[1]))!;
			};
		};
	case => void;
	};
	return target;
};

fn chameleon_find_user(appid: str) str = {
	const base = "/mnt/c/Program Files (x86)/Steam/userdata";
	const ents = match (os::readdir(base)) {
	case let e: []fs::dirent => yield e;
	case => return "";
	};
	defer fs::dirents_free(ents);
	for (let i = 0z; i < len(ents); i += 1) {
		static let pbuf: [512]u8 = [0...];
		const p = fmt::bsprintf(pbuf, "{}/{}/{}", base, ents[i].name, appid)!;
		if (os::exists(p)) {
			return strings::dup(ents[i].name)!;
		};
	};
	return "";
};

fn chameleon_timestamp() str = {
	const now = time::now(time::clock::REALTIME);
	const days = now.sec / 86400;
	const secs_today = now.sec % 86400;
	const hh = secs_today / 3600;
	const mm = (secs_today % 3600) / 60;
	const ss = secs_today % 60;
	static let tbuf: [64]u8 = [0...];
	return fmt::bsprintf(tbuf, "{}_{}-{}-{}", days, hh, mm, ss)!;
};

fn do_chameleon(action: str, target: str, nocolor: bool) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let sdir_buf: [512]u8 = [0...];
	const saves_dir = fmt::bsprintf(sdir_buf, "{}/hpo-saves", home)!;
	os::mkdirs(saves_dir, 0o755)!;

	if (!nocolor) fmt::print("\x1b[35m")!;
	fmt::println("
       .--.
      ( o o )   The Chameleon
       >   <    \"Your power... is now MINE!\"
      /|   |\\
")!;
	if (!nocolor) fmt::print("\x1b[0m")!;

	if (action == "list") {
		cprint("\x1b[34m", "CHAMELEON", "Stolen save powers in the vault:", nocolor);
		fmt::println("")!;
		const ents = match (os::readdir(saves_dir)) {
		case let e: []fs::dirent => yield e;
		case =>
			cprint("\x1b[33m", "CHAMELEON", "No backups yet.", nocolor);
			return;
		};
		defer fs::dirents_free(ents);
		let count = 0;
		for (let i = 0z; i < len(ents); i += 1) {
			fmt::printfln("  save: {}", ents[i].name)!;
			count += 1;
		};
		if (count == 0) cprint("\x1b[33m", "CHAMELEON", "No backups yet.", nocolor);
		return;
	};

	if (len(target) == 0) {
		cprint("\x1b[31m", "ERR", "chameleon backup/restore requires a game alias", nocolor);
		os::exit(1);
	};

	const appid = chameleon_resolve_appid(target);
	const user = chameleon_find_user(appid);
	if (len(user) == 0) {
		cprint("\x1b[31m", "ERR", "No Steam save folder found for this game", nocolor);
		fmt::printfln("  AppID: {}", appid)!;
		os::exit(1);
	};

	static let src_buf: [512]u8 = [0...];
	const src = fmt::bsprintf(src_buf, "/mnt/c/Program Files (x86)/Steam/userdata/{}/{}", user, appid)!;

	if (action == "backup") {
		const ts = chameleon_timestamp();
		static let dst_buf: [512]u8 = [0...];
		const dst = fmt::bsprintf(dst_buf, "{}/{}_{}", saves_dir, appid, ts)!;
		cprint("\x1b[33m", "CHAMELEON", "Absorbing save power...", nocolor);
		fmt::printfln("  From: {}", src)!;
		fmt::printfln("  To:   {}", dst)!;
		fmt::println("")!;
		let args: []str = alloc([], 5)!;
		defer free(args);
		append(args, "cp")!;
		append(args, "-r")!;
		append(args, src)!;
		append(args, dst)!;
		if (run_cmd(args, nocolor)) {
			cprint("\x1b[32m", "OK", "Save power absorbed! The Chameleon grows stronger.", nocolor);
		} else {
			cprint("\x1b[31m", "FAIL", "Backup failed!", nocolor);
			os::exit(1);
		};
		return;
	};

	if (action == "restore") {
		const ents = match (os::readdir(saves_dir)) {
		case let e: []fs::dirent => yield e;
		case =>
			cprint("\x1b[31m", "ERR", "No backups found", nocolor);
			os::exit(1);
		};
		defer fs::dirents_free(ents);
		static let prefix_buf: [128]u8 = [0...];
		const prefix = fmt::bsprintf(prefix_buf, "{}_", appid)!;
		let latest = "";
		static let latest_buf: [256]u8 = [0...];
		for (let i = 0z; i < len(ents); i += 1) {
			if (strings::hasprefix(ents[i].name, prefix)) {
				if (strings::compare(ents[i].name, latest) > 0) {
					latest = fmt::bsprintf(latest_buf, "{}", ents[i].name)!;
				};
			};
		};
		if (len(latest) == 0) {
			cprint("\x1b[31m", "ERR", "No backup found for this game", nocolor);
			os::exit(1);
		};
		static let bsrc_buf: [512]u8 = [0...];
		const bsrc = fmt::bsprintf(bsrc_buf, "{}/{}/.", saves_dir, latest)!;
		cprint("\x1b[33m", "CHAMELEON", "Restoring stolen power...", nocolor);
		fmt::printfln("  From: {}", latest)!;
		fmt::printfln("  To:   {}", src)!;
		fmt::println("")!;
		let args: []str = alloc([], 5)!;
		defer free(args);
		append(args, "cp")!;
		append(args, "-r")!;
		append(args, bsrc)!;
		append(args, src)!;
		if (run_cmd(args, nocolor)) {
			cprint("\x1b[32m", "OK", "Save restored! Power returned.", nocolor);
		} else {
			cprint("\x1b[31m", "FAIL", "Restore failed!", nocolor);
			os::exit(1);
		};
		return;
	};

	cprint("\x1b[31m", "ERR", "Unknown chameleon action (use backup/list/restore)", nocolor);
	os::exit(1);
};
