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
	const cmd = match (exec::cmd("date", "+%Y-%m-%d_%H-%M-%S")) {
	case let c: exec::command => yield c;
	case => return "unknown";
	};
	const pipe = exec::pipe();
	exec::addfile(&cmd, os::stdout_file, pipe.1)!;
	const proc = match (exec::start(&cmd)) {
	case let p: exec::process => yield p;
	case =>
		io::close(pipe.0)!;
		io::close(pipe.1)!;
		return "unknown";
	};
	io::close(pipe.1)!;
	static let tbuf: [64]u8 = [0...];
	const n = match (io::read(pipe.0, tbuf)) {
	case let n: size => yield n;
	case => yield 0z;
	};
	io::close(pipe.0)!;
	exec::wait(&proc)!;
	if (n == 0) return "unknown";
	return strings::dup(strings::trim(strings::fromutf8(tbuf[..n])!))!;
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
			const nm = ents[i].name;
			// Timestamp is always 19 chars (YYYY-MM-DD_HH-MM-SS) preceded by '_'
			let namepart = nm;
			let dt = "";
			if (len(nm) > 20) {
				namepart = strings::sub(nm, 0, len(nm) - 20);
				dt = strings::sub(nm, len(nm) - 19, strings::end);
			};
			if (strings::hasprefix(namepart, "epic_")) {
				const appname = strings::sub(namepart, 5, strings::end);
				const alias = chameleon_epic_alias_for(appname);
				fmt::printfln("  {}  (Epic)  ({})", alias, dt)!;
			} else {
				const gname = steam_game_name(namepart);
				if (len(gname) > 0) {
					fmt::printfln("  {}  ({})", gname, dt)!;
				} else {
					fmt::printfln("  [{}]  ({})", namepart, dt)!;
				};
			};
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
			static let pfx_buf: [128]u8 = [0...];
			const pfx = fmt::bsprintf(pfx_buf, "{}_", appid)!;
			const keepname = fmt::bsprintf(dst_buf, "{}_{}", appid, ts)!;
			chameleon_prune(saves_dir, pfx, keepname, nocolor);
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

fn chameleon_epic_appname(target: str) str = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let abuf: [512]u8 = [0...];
	const apath = fmt::bsprintf(abuf, "{}/.config/hpo/epic_aliases.txt", home)!;
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

fn chameleon_epic_userhash() str = {
	const base = "/mnt/c/Users/ssj3g/AppData/Local/EpicGamesLauncher/Saved/Saves";
	const ents = match (os::readdir(base)) {
	case let e: []fs::dirent => yield e;
	case => return "";
	};
	defer fs::dirents_free(ents);
	for (let i = 0z; i < len(ents); i += 1) {
		return strings::dup(ents[i].name)!;
	};
	return "";
};

fn do_chameleon_epic(action: str, target: str, nocolor: bool) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let sdir_buf: [512]u8 = [0...];
	const saves_dir = fmt::bsprintf(sdir_buf, "{}/hpo-saves", home)!;
	os::mkdirs(saves_dir, 0o755)!;

	if (len(target) == 0) {
		cprint("\x1b[31m", "ERR", "chameleon --epic requires a game alias", nocolor);
		os::exit(1);
	};

	const appname = chameleon_epic_appname(target);
	const hash = chameleon_epic_userhash();
	if (len(hash) == 0) {
		cprint("\x1b[31m", "ERR", "No Epic save folder found (is Epic installed?)", nocolor);
		os::exit(1);
	};

	static let src_buf: [512]u8 = [0...];
	const src = fmt::bsprintf(src_buf, "/mnt/c/Users/ssj3g/AppData/Local/EpicGamesLauncher/Saved/Saves/{}/{}", hash, appname)!;
	if (!os::exists(src)) {
		cprint("\x1b[31m", "ERR", "No Epic cloud-save found for this game", nocolor);
		fmt::printfln("  AppName: {}", appname)!;
		os::exit(1);
	};

	if (action == "backup") {
		const ts = chameleon_timestamp();
		static let dst_buf: [512]u8 = [0...];
		const dst = fmt::bsprintf(dst_buf, "{}/epic_{}_{}", saves_dir, appname, ts)!;
		cprint("\x1b[33m", "CHAMELEON", "Absorbing Epic save power...", nocolor);
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
			cprint("\x1b[32m", "OK", "Epic save power absorbed!", nocolor);
			static let epfx_buf: [256]u8 = [0...];
			const epfx = fmt::bsprintf(epfx_buf, "epic_{}_", appname)!;
			const ekeep = fmt::bsprintf(dst_buf, "epic_{}_{}", appname, ts)!;
			chameleon_prune(saves_dir, epfx, ekeep, nocolor);
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
		static let prefix_buf: [256]u8 = [0...];
		const prefix = fmt::bsprintf(prefix_buf, "epic_{}_", appname)!;
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
			cprint("\x1b[31m", "ERR", "No backup found for this Epic game", nocolor);
			os::exit(1);
		};
		static let bsrc_buf: [512]u8 = [0...];
		const bsrc = fmt::bsprintf(bsrc_buf, "{}/{}/.", saves_dir, latest)!;
		cprint("\x1b[33m", "CHAMELEON", "Restoring Epic save power...", nocolor);
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
			cprint("\x1b[32m", "OK", "Epic save restored!", nocolor);
		} else {
			cprint("\x1b[31m", "FAIL", "Restore failed!", nocolor);
			os::exit(1);
		};
		return;
	};

	cprint("\x1b[31m", "ERR", "Unknown chameleon action (use backup/restore)", nocolor);
	os::exit(1);
};

fn chameleon_epic_alias_for(appname: str) str = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let abuf: [512]u8 = [0...];
	const apath = fmt::bsprintf(abuf, "{}/.config/hpo/epic_aliases.txt", home)!;
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
			if (len(parts) >= 2 && strings::trim(parts[1]) == appname) {
				return strings::dup(strings::trim(parts[0]))!;
			};
		};
	case => void;
	};
	return appname;
};

// Slet alle backups med samme prefix undtagen 'keep'
fn chameleon_prune(saves_dir: str, prefix: str, keep: str, nocolor: bool) void = {
	const ents = match (os::readdir(saves_dir)) {
	case let e: []fs::dirent => yield e;
	case => return;
	};
	defer fs::dirents_free(ents);
	for (let i = 0z; i < len(ents); i += 1) {
		const nm = ents[i].name;
		if (!strings::hasprefix(nm, prefix)) continue;
		if (nm == keep) continue;
		static let old_buf: [512]u8 = [0...];
		const oldpath = fmt::bsprintf(old_buf, "{}/{}", saves_dir, nm)!;
		let args: []str = alloc([], 3)!;
		defer free(args);
		append(args, "rm")!;
		append(args, "-rf")!;
		append(args, oldpath)!;
		let _ = run_cmd(args, nocolor);
		if (!nocolor) fmt::printfln("  \x1b[2m(pruned old backup: {})\x1b[0m", nm)!;
	};
};

fn do_tigress(nocolor: bool) void = {
	const quotes: [_]str = [
		"Finally! A warrior worthy of my time.",
		"There are no accidents. - Oogway",
		"The mark of a true warrior is discipline.",
		"You must believe in yourself before others will.",
		"Strength comes from the inside.",
		"Train hard today, conquer tomorrow.",
		"A focused mind cuts through any obstacle.",
		"Fall seven times, stand up eight.",
		"Master your fear, and you master yourself.",
		"Every day is a chance to grow stronger.",
		"Patience is also a form of action.",
		"The hardest battles are won in silence.",
		"Inner peace is earned, not given.",
		"Push past the limit you set yesterday.",
	];
	const now = time::now(time::clock::REALTIME);
	const day = (now.sec / 86400): size;
	const idx = day % len(quotes);

	if (!nocolor) fmt::print("\x1b[33m")!;
	fmt::println("
      /\\_/\\
     ( o.o )   Master Tigress
      > ^ <    Quote of the Day
")!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	if (!nocolor) fmt::print("\x1b[1m\x1b[36m")!;
	fmt::printfln("  \"{}\"", quotes[idx])!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	if (!nocolor) fmt::print("\x1b[2m")!;
	fmt::println("                          - Master Tigress")!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	fmt::println("")!;
};

fn do_tailung(urls: []str, nocolor: bool) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let ddir_buf: [512]u8 = [0...];
	const dl_dir = fmt::bsprintf(ddir_buf, "{}/Downloads", home)!;
	os::mkdirs(dl_dir, 0o755)!;

	if (!nocolor) fmt::print("\x1b[36m")!;
	fmt::println("
     /\\___/\\
    (  o o  )   TAI LUNG
    (  =^=  )   Unleashed - all at once!
     (______)
")!;
	if (!nocolor) fmt::print("\x1b[0m")!;

	const count = len(urls);
	if (count == 0) {
		cprint("\x1b[31m", "ERR", "Tai Lung needs at least one URL", nocolor);
		os::exit(1);
	};

	cprint("\x1b[33m", "TAILUNG", "Breaking out! Launching all downloads at once...", nocolor);
	fmt::printfln("  Targets: {}", count)!;
	fmt::println("")!;

	// Start alle downloads samtidigt
	let procs: []exec::process = alloc([], count)!;
	defer free(procs);
	let names: []str = alloc([], count)!;
	defer free(names);

	for (let i = 0z; i < count; i += 1) {
		const url = urls[i];
		// Udled filnavn
		const slash = match (strings::rindex(url, '/')) {
		case let x: size => yield x + 1;
		case void => yield 0z;
		};
		let fname = strings::sub(url, slash, strings::end);
		const q = match (strings::index(fname, '?')) {
		case let x: size => yield x;
		case void => yield len(fname);
		};
		fname = strings::sub(fname, 0, q);
		if (len(fname) == 0) fname = "download";
		const outpath = fmt::asprintf("{}/{}", dl_dir, fname)!;
		append(names, outpath)!;

		const cmd = match (exec::cmd("curl", "-g", "-sL", "-o", outpath, url)) {
		case let c: exec::command => yield c;
		case =>
			cprint("\x1b[31m", "ERR", "failed to build curl command", nocolor);
			continue;
		};
		const proc = match (exec::start(&cmd)) {
		case let p: exec::process => yield p;
		case =>
			cprint("\x1b[31m", "ERR", "failed to start download", nocolor);
			continue;
		};
		append(procs, proc)!;
		fmt::printfln("  \x1b[2m-> started: {}\x1b[0m", fname)!;
	};

	fmt::println("")!;
	cprint("\x1b[36m", "TAILUNG", "All strikes launched! Waiting for completion...", nocolor);
	fmt::println("")!;

	// Vent på dem alle
	let ok = 0;
	let fail = 0;
	for (let i = 0z; i < len(procs); i += 1) {
		const st = match (exec::wait(&procs[i])) {
		case let s: exec::status => yield s;
		case =>
			fail += 1;
			continue;
		};
		match (exec::exit(&st)) {
		case let e: exec::exited =>
			if (e == 0) {
				ok += 1;
				fmt::printfln("  \x1b[32m[done]\x1b[0m {}", names[i])!;
			} else {
				fail += 1;
				fmt::printfln("  \x1b[31m[fail]\x1b[0m {}", names[i])!;
			};
		case =>
			fail += 1;
		};
	};

	fmt::println("")!;
	static let sum_buf: [128]u8 = [0...];
	const summary = fmt::bsprintf(sum_buf, "Tai Lung strikes complete! {} done, {} failed.", ok, fail)!;
	cprint("\x1b[32m", "OK", summary, nocolor);
};

fn piyoko_path() str = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let pbuf: [512]u8 = [0...];
	return fmt::bsprintf(pbuf, "{}/.config/hpo/piyokocoin", home)!;
};

fn piyoko_balance() u64 = {
	const path = piyoko_path();
	match (os::open(path)) {
	case let f: io::file =>
		static let rbuf: [64]u8 = [0...];
		const n = match (io::read(f, rbuf)) {
		case let n: size => yield n;
		case => yield 0z;
		};
		io::close(f)!;
		if (n == 0) return 0;
		const s = strings::trim(strings::fromutf8(rbuf[..n])!);
		let val: u64 = 0;
		const bytes = strings::toutf8(s);
		for (let i = 0z; i < len(bytes); i += 1) {
			if (bytes[i] >= '0' && bytes[i] <= '9') {
				val = val * 10 + (bytes[i] - '0'): u64;
			};
		};
		return val;
	case => return 0;
	};
};

fn piyoko_save(bal: u64) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void => yield "/tmp";
	};
	static let cfgbuf: [512]u8 = [0...];
	const cfgdir = fmt::bsprintf(cfgbuf, "{}/.config/hpo", home)!;
	os::mkdirs(cfgdir, 0o755)!;
	const path = piyoko_path();
	match (os::create(path, 0o644)) {
	case let f: io::file =>
		const s = fmt::asprintf("{}", bal)!;
		defer free(s);
		io::writeall(f, strings::toutf8(s))!;
		io::close(f)!;
	case => void;
	};
};

// Tjen coins (kaldes efter download/launch). Stille - ingen output.
fn piyoko_earn(amount: u64) void = {
	const bal = piyoko_balance();
	piyoko_save(bal + amount);
};

fn do_piyoko(nocolor: bool) void = {
	const bal = piyoko_balance();
	if (!nocolor) fmt::print("\x1b[93m")!;
	fmt::println("
        \x1b[33m\u2584\u2584\u2584\u2584\u2584\x1b[0m
      \x1b[93m\u2588\u2588\x1b[33m\u2588\u2588\u2588\x1b[93m\u2588\u2588\x1b[0m
    \x1b[93m\u2588\u2588\x1b[33m\u2588\x1b[93m\u2588\u2588\u2588\x1b[33m\u2588\x1b[93m\u2588\u2588\x1b[0m
    \x1b[93m\u2588\u2588\x1b[33m\u2588\x1b[30m\u25cf\x1b[33m\u2588\x1b[30m\u25cf\x1b[33m\u2588\x1b[93m\u2588\u2588\x1b[0m
    \x1b[93m\u2588\u2588\x1b[33m\u2588\x1b[38;5;208m\u25c6\x1b[33m\u2588\u2588\x1b[93m\u2588\u2588\x1b[0m
    \x1b[93m\u2588\u2588\x1b[33m\u2588\u2588\u2588\u2588\u2588\x1b[93m\u2588\u2588\x1b[0m
      \x1b[93m\u2588\u2588\x1b[33m\u2588\u2588\u2588\x1b[93m\u2588\u2588\x1b[0m
        \x1b[33m\u2580\u2580\u2580\u2580\u2580\x1b[0m
              \x1b[1m\x1b[93mPIYOKOCOIN\x1b[0m
")!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	if (!nocolor) fmt::print("\x1b[1m\x1b[33m")!;
	fmt::printfln("  Balance: {} Piyokocoin", bal)!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	if (!nocolor) fmt::print("\x1b[2m")!;
	fmt::println("  (earn more by using hpo!)")!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	fmt::println("")!;
};

fn do_piyoko_spin(nocolor: bool) void = {
	let bal = piyoko_balance();
	if (bal < 1) {
		if (!nocolor) fmt::print("\x1b[31m")!;
		fmt::println("
    (\\(\\
    ( ;.;)   Piyoko
    o_(\")(\")  No coins to spin!
")!;
		if (!nocolor) fmt::print("\x1b[0m")!;
		cprint("\x1b[33m", "PIYOKO", "Earn coins by downloading first!", nocolor);
		return;
	};

	// Indsats: 1 PYO
	bal -= 1;

	// Tilfældighed: seed fra nanosekunder
	const now = time::now(time::clock::REALTIME);
	let seed = (now.nsec: u64) ^ (now.sec: u64 * 2654435761);

	const symbols: [_]str = ["🐤", "🪙", "🥚", "⭐"];
	let reels: [3]size = [0, 0, 0];
	for (let i = 0z; i < 3; i += 1) {
		// Simpel LCG-step
		seed = (seed * 6364136223846793005 + 1442695040888963407);
		reels[i] = ((seed >> 33): size) % len(symbols);
	};

	if (!nocolor) fmt::print("\x1b[1m\x1b[33m")!;
	fmt::println("
    === PIYOKOCOIN SPIN ===")!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	fmt::println("    Duty! The chicken spins...")!;
	fmt::println("")!;
	fmt::printfln("      [ {} | {} | {} ]", symbols[reels[0]], symbols[reels[1]], symbols[reels[2]])!;
	fmt::println("")!;

	// Beregn gevinst
	let payout: u64 = 0;
	if (reels[0] == reels[1] && reels[1] == reels[2]) {
		payout = 10;
		if (!nocolor) fmt::print("\x1b[1m\x1b[32m")!;
		fmt::println("    🎉 JACKPOT! Three of a kind! +10 PYO 🎉")!;
		if (!nocolor) fmt::print("\x1b[0m")!;
	} else if (reels[0] == reels[1] || reels[1] == reels[2] || reels[0] == reels[2]) {
		payout = 3;
		if (!nocolor) fmt::print("\x1b[32m")!;
		fmt::println("    Nice! A pair! +3 PYO")!;
		if (!nocolor) fmt::print("\x1b[0m")!;
	} else {
		if (!nocolor) fmt::print("\x1b[31m")!;
		fmt::println("    No match. Better luck next time!")!;
		if (!nocolor) fmt::print("\x1b[0m")!;
	};

	bal += payout;
	piyoko_save(bal);

	fmt::println("")!;
	if (!nocolor) fmt::print("\x1b[1m\x1b[33m")!;
	fmt::printfln("    Balance: {} PYO", bal)!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	if (!nocolor) fmt::print("\x1b[2m")!;
	fmt::println("    🐤 \"Duty!\" — Every coin earned with honor.")!;
	if (!nocolor) fmt::print("\x1b[0m")!;
	fmt::println("")!;
};
