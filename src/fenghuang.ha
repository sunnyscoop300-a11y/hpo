// Fenghuang — hpo system package updater wrapper

use fmt;
use os;
use os::exec;

fn do_fenghuang(o: *opts) void = {
	const home = match (os::getenv("HOME")) {
	case let s: str => yield s;
	case void =>
		fmt::errorln("Fenghuang: HOME ikke sat")!;
		return;
	};
	const helper = fmt::asprintf("{}/hpo/helpers/fenghuang.py", home)!;
	defer free(helper);

	if (o.fenghuang_arg3 != "") {
		const cmd = exec::cmd("python3", helper,
			o.fenghuang_arg, o.fenghuang_arg2, o.fenghuang_arg3)!;
		const proc = exec::start(&cmd)!;
		exec::wait(&proc)!;
	} else if (o.fenghuang_arg2 != "") {
		const cmd = exec::cmd("python3", helper,
			o.fenghuang_arg, o.fenghuang_arg2)!;
		const proc = exec::start(&cmd)!;
		exec::wait(&proc)!;
	} else if (o.fenghuang_arg != "") {
		const cmd = exec::cmd("python3", helper, o.fenghuang_arg)!;
		const proc = exec::start(&cmd)!;
		exec::wait(&proc)!;
	} else {
		const cmd = exec::cmd("python3", helper)!;
		const proc = exec::start(&cmd)!;
		exec::wait(&proc)!;
	};
};
