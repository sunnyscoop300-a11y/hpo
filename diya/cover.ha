// Bogomslag til reolen.
//   EPUB 3:  <item properties="cover-image" href="...">
//   EPUB 2:  <meta name="cover" content="ID">  +  <item id="ID" href="...">
//   CBZ/CBR: første billede i naturlig rækkefølge
// Stien er relativ til bogens mappe i ~/.cache/diya, så /img kan sende den.
use bytes;
use fs;
use os;
use strings;

// Forsidens sti, eller void hvis bogen ikke har en. Kalderen frigør.
fn book_cover(name: str) (str | void) = {
	if (strings::hassuffix(name, ".epub")) return epub_cover(name);
	if (is_comic(name)) return comic_cover(name);
	return;
};

fn epub_cover(name: str) (str | void) = {
	const dir = match (epub_dir(name)) {
	case let d: str =>
		yield d;
	case void =>
		return;
	};
	defer free(dir);

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
	const opfdir = dirname(opfrel);

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

	let coverid: []u8 = [];
	let ids: [][]u8 = [];
	defer free(ids);
	let hrefs: [][]u8 = [];
	defer free(hrefs);

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
			const href = match (attr(tag, "href")) {
			case let h: []u8 =>
				yield h;
			case void =>
				continue;
			};
			// EPUB 3: forsiden er markeret direkte
			match (attr(tag, "properties")) {
			case let p: []u8 =>
				if (bytes::index(p, strings::toutf8("cover-image")) is size) {
					return resolve(opfdir, href);
				};
			case void => void;
			};
			match (attr(tag, "id")) {
			case let id: []u8 =>
				append(ids, id)!;
				append(hrefs, href)!;
			case void => void;
			};
		} else if (same(tn, "meta")) {
			// EPUB 2: <meta name="cover" content="ID">
			match (attr(tag, "name")) {
			case let n: []u8 =>
				if (same(n, "cover")) {
					match (attr(tag, "content")) {
					case let c: []u8 =>
						coverid = c;
					case void => void;
					};
				};
			case void => void;
			};
		};
	};

	if (len(coverid) == 0) return;
	for (let j = 0z; j < len(ids); j += 1) {
		if (bytes::equal(ids[j], coverid)) return resolve(opfdir, hrefs[j]);
	};
	return;
};

fn comic_cover(name: str) (str | void) = {
	const dir = match (comic_dir(name)) {
	case let d: str =>
		yield d;
	case void =>
		return;
	};
	defer free(dir);
	const ents = match (os::readdir(dir)) {
	case let e: []fs::dirent =>
		yield e;
	case =>
		return;
	};
	defer fs::dirents_free(ents);

	let best = "";
	for (let i = 0z; i < len(ents); i += 1) {
		const n = ents[i].name;
		if (strings::hasprefix(n, ".") || !is_image(n)) continue;
		if (len(best) == 0 || natcmp(n, best) < 0) best = n;
	};
	if (len(best) == 0) return;
	return strings::dup(best)!;
};
