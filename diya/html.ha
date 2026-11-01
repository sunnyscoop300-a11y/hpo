// Alt HTML genereres her — browseren får færdige sider.
use fmt;
use io;
use strconv;
use strings;

const QUOTES: [_]str = [
	"En god tyv læser altid det med småt.",
	"Vedhænget var aldrig målet. Historien var.",
	"Kantinen er lukket. Læsehjørnet er åbent.",
	"Rukhmini siger jeg snyder. Jeg siger jeg bladrer hurtigt.",
	"Padma, sæt dig ned. Det her kapitel er godt.",
	"Jayesh ville have halvdelen af byen. Jeg tager hellere en side mere.",
	"Man stjæler ikke en god bog. Man låner den for altid.",
];

// Diyas mærke: guldring med rød bindi
def LOGO: str = `<svg class="logo" viewBox="0 0 64 64" aria-hidden="true">
<circle cx="32" cy="32" r="27" fill="none" stroke="var(--gold)" stroke-width="3"/>
<circle cx="32" cy="32" r="20" fill="none" stroke="var(--gold)" stroke-width="1" stroke-dasharray="2 4"/>
<path d="M32 12 C40 24 40 40 32 52 C24 40 24 24 32 12Z" fill="var(--gold)" opacity=".25"/>
<circle cx="32" cy="32" r="6" fill="var(--bindi)"/></svg>`;

def CSS: str = `<style>
:root{--fs:20px}
.t-kantine{--bg:#24101a;--paper:#331622;--ink:#f1e2c4;--soft:#c9a98a;--gold:#d9a441;--bindi:#d4362f;--line:#4d2535}
.t-nat{--bg:#100e15;--paper:#191621;--ink:#ddd6ea;--soft:#9a91ad;--gold:#c9a052;--bindi:#c8443c;--line:#2a2535}
.t-dag{--bg:#eadcbc;--paper:#f8f0dc;--ink:#3a291c;--soft:#7d6248;--gold:#9a6a1f;--bindi:#b8312a;--line:#dccaa2}
*{box-sizing:border-box}
html,body{margin:0}
body{background:var(--bg);color:var(--ink);font-family:"Iowan Old Style","Palatino Linotype",Palatino,"Book Antiqua",Georgia,serif;min-height:100vh}
body.t-kantine{background:radial-gradient(ellipse at top,#3b1828,#1c0c14 70%) fixed}
a{color:var(--gold)}
.ui{font-family:system-ui,"Segoe UI",sans-serif}
.wrap{max-width:860px;margin:0 auto;padding:40px 16px 64px}
.logo{width:64px;height:64px;flex:none}
.lib-head{display:flex;gap:18px;align-items:center;margin-bottom:36px}
.lib-head h1{margin:0;font-size:44px;letter-spacing:.35em;color:var(--gold);font-weight:600}
.tag{margin:4px 0 0;color:var(--soft);font-style:italic}
.continue{display:flex;flex-direction:column;gap:4px;padding:18px 22px;margin-bottom:28px;border:1px solid var(--gold);border-radius:14px;text-decoration:none;color:var(--ink);background:var(--paper)}
.continue span{font:600 12px system-ui,sans-serif;letter-spacing:.14em;text-transform:uppercase;color:var(--gold)}
.continue strong{font-size:22px;font-weight:500}
.shelf{list-style:none;padding:0;margin:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:16px}
.shelf a{position:relative;display:flex;flex-direction:column;gap:10px;min-height:150px;padding:18px 18px 16px 30px;background:var(--paper);border:1px solid var(--line);border-radius:6px 14px 14px 6px;text-decoration:none;color:var(--ink);transition:transform .15s,border-color .15s}
.shelf a:hover{transform:translateY(-3px);border-color:var(--gold)}
.spine{position:absolute;left:0;top:0;bottom:0;width:12px;border-radius:6px 0 0 6px;background:linear-gradient(var(--gold),var(--bindi))}
.shelf .t{font-size:19px;line-height:1.3;flex:1}
.meta{font:13px system-ui,sans-serif;color:var(--soft)}
.bar{height:4px;background:var(--line);border-radius:4px;overflow:hidden}
.bar i{display:block;height:100%;background:var(--gold)}
.empty{padding:28px;border:1px dashed var(--line);border-radius:14px;color:var(--soft);line-height:1.6}
code{background:var(--paper);padding:2px 6px;border-radius:4px;font-size:.9em}
footer{margin-top:48px;color:var(--soft);font:14px system-ui,sans-serif;display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap}
.quote{color:var(--soft);font-style:italic;text-align:center;margin:28px 0 0}
.quote::before{content:"— ";color:var(--bindi)}
.reader{max-width:calc(var(--fs)*34);margin:0 auto;padding:0 16px 48px}
.top{position:sticky;top:0;display:flex;align-items:center;gap:12px;padding:12px 0;background:var(--bg);border-bottom:1px solid var(--line);font:14px system-ui,sans-serif;z-index:2}
.top a{text-decoration:none}
.booktitle{flex:1;text-align:center;color:var(--soft);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.tools{display:flex;gap:6px}
.tools a{display:inline-flex;align-items:center;justify-content:center;min-width:34px;height:30px;padding:0 8px;border:1px solid var(--line);border-radius:8px;color:var(--ink)}
.tools a.on{border-color:var(--gold);color:var(--gold)}
article{font-size:var(--fs);line-height:1.7;padding:36px 0 12px;hyphens:auto;text-align:justify}
article p{margin:0;text-indent:1.4em}
article p:first-child,article h2+p{text-indent:0}
article>p:first-child::first-letter{color:var(--gold);font-size:2.4em;float:left;line-height:1;margin:.05em .08em 0 0}
article h2{font-weight:500;color:var(--gold);text-align:center;letter-spacing:.12em;margin:.4em 0 1.2em;font-size:1.25em}
article h2::after{content:"";display:block;width:8px;height:8px;margin:14px auto 0;border-radius:50%;background:var(--bindi)}
.bottom{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:18px 0 10px;font:14px system-ui,sans-serif;color:var(--soft)}
.bottom a,.bottom .off{padding:8px 14px;border:1px solid var(--line);border-radius:10px;text-decoration:none}
.bottom .off{opacity:.4}
.bottom input{width:4.2em;background:var(--paper);color:var(--ink);border:1px solid var(--line);border-radius:6px;padding:4px;font:inherit;text-align:center}
.done{text-align:center;color:var(--gold);margin:24px 0 0;font-style:italic}
.pic{margin:0 0 1em;text-align:center}
.pic img{display:block;margin:0 auto;max-width:100%;max-height:calc(100vh - 150px);border-radius:6px;box-shadow:0 6px 28px rgba(0,0,0,.35)}
.fx{position:relative;margin:0 auto 1em;max-width:100%;overflow:hidden;border-radius:6px;background:#fff;box-shadow:0 6px 28px rgba(0,0,0,.35)}
.stage{position:relative}
.zone{position:absolute;top:0;bottom:0;z-index:1}
.zone.prev{left:0;width:30%;cursor:w-resize}
.zone.next{right:0;width:70%;cursor:e-resize}
.mk{display:block;width:1px;height:1px;opacity:0}
.fx iframe{position:absolute;top:0;left:0;border:0;transform-origin:0 0;pointer-events:none}
.rul .pg{position:relative;padding-bottom:28px;margin-bottom:28px;border-bottom:1px dashed var(--line)}
.rul .pg:last-child{border-bottom:0}
.rul p:first-child::first-letter{color:inherit;font-size:inherit;float:none;margin:0}
.pgno{position:absolute;bottom:4px;right:0;font:12px system-ui,sans-serif;color:var(--soft)}
.linkbtn{background:none;border:0;padding:0;color:var(--gold);font:inherit;text-decoration:underline;cursor:pointer}
@media(max-width:560px){.tools a.sw{display:none}.lib-head h1{font-size:34px}}
</style>`;

// HTML-escape, byte for byte (sikkert for UTF-8: de farlige tegn er ASCII)
fn esc(h: io::handle, s: str) void = {
	const b = strings::toutf8(s);
	let start = 0z;
	for (let i = 0z; i < len(b); i += 1) {
		let rep = "";
		if (b[i] == 0x26) {
			rep = "&amp;";
		} else if (b[i] == 0x3C) {
			rep = "&lt;";
		} else if (b[i] == 0x3E) {
			rep = "&gt;";
		} else if (b[i] == 0x22) {
			rep = "&quot;";
		} else {
			continue;
		};
		putb(h, b[start..i]);
		put(h, rep);
		start = i + 1;
	};
	putb(h, b[start..]);
};

// "mit_bedste_eventyr.txt" -> "mit bedste eventyr"
fn title(h: io::handle, name: str) void = {
	const t = display_title(name);
	esc(h, t);
	free(t);
};

fn page_start(c: io::handle, pagetitle: str) void = {
	send_head(c, "200 OK", "text/html; charset=utf-8");
	const tema = theme();
	defer free(tema);
	put(c, "<!doctype html><html lang=\"da\"><head><meta charset=\"utf-8\">"
		"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>");
	esc(c, pagetitle);
	put(c, " · Diya</title>");
	put(c, CSS);
	putf(c, "</head><body class=\"t-{}\" style=\"--fs:{}px\">", tema, fontsize());
};

fn page_end(c: io::handle) void = put(c, "</body></html>\n");

// Link til en bog; i rulle-mode med #sN så browseren hopper til bogmærket
fn bookhref(c: io::handle, i: size, name: str) void = {
	const (pg, _) = progress(name);
	if (scrollmode() && pg > 1) {
		putf(c, "/laes?bog={}#s{}", i, pg);
	} else {
		putf(c, "/laes?bog={}", i);
	};
};

fn page_library(c: io::handle) void = {
	const books = list_books();
	defer strings::freeall(books);

	page_start(c, "Biblioteket");
	put(c, "<div class=\"wrap\"><header class=\"lib-head\">");
	put(c, LOGO);
	put(c, "<div><h1>DIYA</h1><p class=\"tag\">Læsehjørnet bag Villains' Canteen</p></div></header>");

	match (kv_get("sidst")) {
	case let last: str =>
		for (let i = 0z; i < len(books); i += 1) {
			if (books[i] != last) continue;
			const (pg, tot) = progress(books[i]);
			put(c, "<a class=\"continue\" href=\"");
			bookhref(c, i, books[i]);
			put(c, "\"><span>Fortsæt hvor du slap</span><strong>");
			title(c, books[i]);
			putf(c, "</strong><em class=\"meta\">side {} af {}</em></a>", pg, tot);
			break;
		};
		free(last);
	case void => void;
	};

	if (len(books) == 0) {
		put(c, "<div class=\"empty ui\"><strong>Reolen er tom.</strong><br>"
			"Læg <code>.epub</code>-, <code>.txt</code>- eller <code>.md</code>-bøger i <code>");
		esc(c, bookdir);
		put(c, "</code> og genindlæs siden.</div>");
	} else {
		put(c, "<ul class=\"shelf\">");
		for (let i = 0z; i < len(books); i += 1) {
			const (pg, tot) = progress(books[i]);
			put(c, "<li><a href=\"");
			bookhref(c, i, books[i]);
			put(c, "\"><span class=\"spine\"></span><span class=\"t\">");
			title(c, books[i]);
			put(c, "</span>");
			if (tot == 0) {
				put(c, "<span class=\"meta\">Ikke åbnet endnu</span>"
					"<span class=\"bar\"><i style=\"width:0\"></i></span>");
			} else {
				const pct = pg * 100 / tot;
				putf(c, "<span class=\"meta\">side {} af {} · {}%</span>"
					"<span class=\"bar\"><i style=\"width:{}%\"></i></span>",
					pg, tot, pct, pct);
			};
			put(c, "</a></li>");
		};
		put(c, "</ul>");
	};

	put(c, "<footer><span>Bøger fra <code>");
	esc(c, bookdir);
	putf(c, "</code> · {} i alt</span><form method=\"post\" action=\"/luk?k={}\">"
		"<button class=\"linkbtn\">Luk Diya</button></form></footer>", len(books), token);
	putf(c, "<p class=\"quote\">{}</p></div>", QUOTES[len(books) % len(QUOTES)]);
	page_end(c);
};

fn page_reader(c: io::handle, q: str) void = {
	const books = list_books();
	defer strings::freeall(books);

	const bi = match (qnum(q, "bog")) {
	case let n: size =>
		yield n;
	case void =>
		yield len(books);
	};
	if (bi >= len(books)) {
		redirect(c, "/");
		return;
	};
	const name = books[bi];

	let b = match (load_book(name)) {
	case let b: book =>
		yield b;
	case void =>
		page_start(c, "Hov");
		put(c, "<div class=\"wrap\"><p class=\"empty ui\">Diya kunne ikke læse den bog "
			"(er den UTF-8?). <a href=\"/\">Tilbage</a></p></div>");
		page_end(c);
		return;
	};
	defer book_free(&b);

	const total = len(b.pages);
	// side fra URL'en (1-baseret), ellers bogmærket
	let p: size = match (qnum(q, "side")) {
	case let n: size =>
		yield if (n == 0) 0z else n - 1;
	case void =>
		const (saved, _) = progress(name);
		yield if (saved == 0) 0z else saved - 1;
	};
	if (p >= total) p = total - 1;
	save_progress(name, p + 1, total);

	const tabtitle = display_title(name);
	defer free(tabtitle);
	page_start(c, tabtitle);
	const tema = theme();
	defer free(tema);

	put(c, "<div class=\"reader\"><nav class=\"top\"><a id=\"hjem\" href=\"/\">← Biblioteket</a>"
		"<span class=\"booktitle\">");
	title(c, name);
	put(c, "</span><span class=\"tools\">");
	// i rulle-mode udelades side, så Hare bruger det bogmærke JS'en har gemt
	const rul = scrollmode();
	const px = fontsize();
	const sp = if (rul) strings::dup("")! else fmt::asprintf("&side={}", p + 1)!;
	defer free(sp);
	const themes: [_]str = ["dag", "nat", "kantine"];
	const labels: [_]str = ["Dag", "Nat", "Kantine"];
	for (let i = 0z; i < len(themes); i += 1) {
		putf(c, "<a class=\"sw{}\" href=\"/tema?t={}&bog={}{}\">{}</a>",
			if (tema == themes[i]) " on" else "",
			themes[i], bi, sp, labels[i]);
	};
	putf(c, "<a href=\"/str?d=ned&bog={}{}\" title=\"Mindre skrift\">A−</a>", bi, sp);
	putf(c, "<a href=\"/str?d=op&bog={}{}\" title=\"Større skrift\">A+</a>", bi, sp);
	putf(c, "<a class=\"{}\" href=\"/visning?v={}&bog={}{}\" title=\"{}\">⇣ Rul</a>",
		if (rul) "on" else "",
		if (rul) "sider" else "rul", bi, sp,
		if (rul) "Skift til side for side" else "Skift til rul med musen");
	put(c, "</span></nav>");

	if (rul) {
		// Hele bogen på én lang side — man ruller med musen
		put(c, "<article class=\"rul\">");
		for (let pg = 0z; pg < total; pg += 1) {
			putf(c, "<section class=\"pg\" id=\"s{}\">", pg + 1);
			// usynlig "lazy" pixel: browseren henter den først når siden nærmer
			// sig skærmen, og så ved Hare hvor langt man er nået
			putf(c, "<img class=\"mk\" loading=\"lazy\" alt=\"\" "
				"src=\"/mark?bog={}&side={}&af={}\">", bi, pg + 1, total);
			const (s0, e0) = page_range(&b, pg);
			render_chunks(c, &b, bi, s0, e0, true, px);
			putf(c, "<div class=\"pgno\">{}</div></section>", pg + 1);
		};
		put(c, "</article><p class=\"done\">Slut. Diya lukker bogen med et tilfreds suk.</p>");
		putf(c, "<p class=\"quote\">{}</p></div>", QUOTES[p % len(QUOTES)]);
		page_end(c);
		return;
	};

	// klik venstre del = forrige, højre del = næste
	put(c, "<div class=\"stage\">");
	if (p > 0) {
		putf(c, "<a class=\"zone prev\" href=\"/laes?bog={}&side={}\" aria-label=\"Forrige\"></a>", bi, p);
	};
	if (p + 1 < total) {
		putf(c, "<a class=\"zone next\" href=\"/laes?bog={}&side={}\" aria-label=\"Næste\"></a>", bi, p + 2);
	};
	put(c, "<article>");
	const (start, end) = page_range(&b, p);
	render_chunks(c, &b, bi, start, end, false, px);
	put(c, "</article></div>");

	if (p + 1 == total) {
		put(c, "<p class=\"done\">Slut. Diya lukker bogen med et tilfreds suk.</p>");
	};

	put(c, "<nav class=\"bottom\">");
	if (p > 0) {
		putf(c, "<a id=\"forrige\" accesskey=\"f\" href=\"/laes?bog={}&side={}\">‹ Forrige</a>", bi, p);
	} else {
		put(c, "<span class=\"off\">‹ Forrige</span>");
	};
	putf(c, "<form action=\"/laes\"><input type=\"hidden\" name=\"bog\" value=\"{}\">"
		"side <input name=\"side\" type=\"number\" min=\"1\" max=\"{}\" value=\"{}\"> af {}</form>",
		bi, total, p + 1, total);
	if (p + 1 < total) {
		putf(c, "<a id=\"naeste\" accesskey=\"n\" href=\"/laes?bog={}&side={}\">Næste ›</a>", bi, p + 2);
	} else {
		put(c, "<span class=\"off\">Næste ›</span>");
	};
	putf(c, "</nav><div class=\"bar\"><i style=\"width:{}%\"></i></div>", (p + 1) * 100 / total);
	putf(c, "<p class=\"quote\">{}</p></div>", QUOTES[p % len(QUOTES)]);
	page_end(c);
};

// Skriver chunks [start, end). lazy = lad browseren hente billeder/sider først når de er tæt på
fn render_chunks(c: io::handle, b: *book, bi: size, start: size, end: size,
		lazy: bool, px: size) void = {
	const ld = if (lazy) " loading=\"lazy\"" else "";
	for (let j = start; j < end; j += 1) {
		switch (b.kinds[j]) {
		case kind::HEAD =>
			put(c, "<h2>");
			esc(c, b.chunks[j]);
			put(c, "</h2>");
		case kind::IMG =>
			putf(c, "<figure class=\"pic\"><img{} src=\"/img?bog={}&f=", ld, bi);
			urlenc(c, b.chunks[j]);
			put(c, "\" alt=\"\"></figure>");
		case kind::PAGE =>
			const (w, r1) = strings::cut(b.chunks[j], " ");
			const (hh, rel) = strings::cut(r1, " ");
			const wn = match (strconv::stoz(w)) {
			case let n: size =>
				yield n;
			case =>
				yield 1000z;
			};
			const hn = match (strconv::stoz(hh)) {
			case let n: size =>
				yield n;
			case =>
				yield 1500z;
			};
			// Hare regner skaleringen ud: siden bliver px*45 høj, så A−/A+ zoomer
                    	let th = px * 45;
			let tw = wn * th / hn;
			// aldrig bredere end læsefeltet (px*34 minus 2*16 px kant)
			const maxw = px * 34 - 32;
			if (tw > maxw) {
				tw = maxw;
				th = hn * tw / wn;
			};
			const sc = tw: f64 / wn: f64;
     			putf(c, "<div class=\"fx\" style=\"width:{}px;height:{}px\">", tw, th);
			putf(c, "<iframe{} width=\"{}\" height=\"{}\" scrolling=\"no\" "
				"sandbox=\"allow-same-origin\" style=\"transform:scale({})\" "
				"src=\"/epub/{}/", ld, wn, hn, sc, bi);
			urlenc(c, rel);
			put(c, "\"></iframe></div>");
		case kind::TEXT =>
			put(c, "<p>");
			esc(c, b.chunks[j]);
			put(c, "</p>");
		};
	};
};

fn page_bye(c: io::handle) void = {
	page_start(c, "Farvel");
	put(c, "<div class=\"wrap\" style=\"text-align:center;padding-top:20vh\">");
	put(c, LOGO);
	put(c, "<h1 style=\"color:var(--gold);letter-spacing:.3em\">DIYA</h1>"
		"<p class=\"quote\">Kantinen er lukket for i aften. Bogmærkerne er gemt.</p></div>");
	page_end(c);
};

fn page_luk(c: io::handle) void = {
	page_start(c, "Luk");
	put(c, "<div class=\"wrap\" style=\"text-align:center;padding-top:20vh\">");
	putf(c, "<form method=\"post\" action=\"/luk?k={}\"><button class=\"linkbtn\">Ja, luk Diya</button></form>", token);
	put(c, "<p><a href=\"/\">Nej, tilbage til reolen</a></p></div>");
	page_end(c);
};

fn page_notfound(c: io::handle) void = {
	send_head(c, "404 Not Found", "text/html; charset=utf-8");
	put(c, "<!doctype html><meta charset=\"utf-8\"><title>404 · Diya</title>"
		"<p>Selv Diya kan ikke stjæle en side der ikke findes. <a href=\"/\">Tilbage</a></p>");
};
