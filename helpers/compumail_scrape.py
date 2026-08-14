#!/usr/bin/env python3
"""
compumail_scrape.py — two-level scraper for compumail.dk:

  1. Visits /da/campaigns and collects links to each active campaign
     (e.g. /da/campaign/weekenddeals).
  2. Visits each campaign page and pulls out product name + price
     pairs using a generic heuristic (rather than hand-picked CSS
     classes): find every element whose own text looks like a Danish
     price ("1.299,00 kr" / "1299 DKK" / etc.), then walk up the DOM
     to the nearest ancestor that also contains a product link/title,
     and use that as the product name. This avoids needing to
     view-source and hand-pick class names — same idea as vindhjelm's
     marker-hunting in Hare, just automated via a real DOM instead of
     raw byte offsets.

Setup (one-time, same as happii_scrape.py):
    pip install playwright --break-system-packages
    playwright install chromium

Run:
    python3 compumail_scrape.py
"""

import re
import sys

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Playwright er ikke installeret. Kør:")
    print("  pip install playwright --break-system-packages")
    print("  playwright install chromium")
    sys.exit(1)

BASE = "https://compumail.dk"
CAMPAIGNS_URL = f"{BASE}/da/campaigns"

# Danish price shape: thousands separated by '.' or a (possibly
# non-breaking) space, decimals always ',XX'. Deliberately does NOT
# require a currency word/symbol in the same match: on compumail.dk
# the "DKK" label turned out to be CSS-generated content (a ::before
# pseudo-element) that shows up in page.inner_text() but isn't a real
# DOM text node, so a TreeWalker over text nodes never sees "DKK" and
# the number together. Comma-plus-exactly-two-decimals is specific
# enough to Danish currency amounts (dates use dashes, stock counts
# have no decimals) to stand on its own.
PRICE_RE = re.compile(
    r"\d{1,3}(?:[.\s]\d{3})*,\d{2}\b",
)

MAX_CAMPAIGNS = 5  # cap how many campaign pages we crawl per run
MAX_DEALS_PER_CAMPAIGN = 12


def dismiss_cookie_banner(page):
    """CookieInformation (used on compumail.dk, per the debug HTML) often
    overlays the page until a choice is made, which can keep the real
    content from rendering/loading. Try a handful of common Danish/
    English accept-button texts; ignore failures — if there's no
    banner, there's nothing to dismiss."""
    candidates = [
        "Accepter alle", "Tillad alle", "Accepter alle cookies",
        "Accept all", "Allow all", "Godkend alle",
    ]
    for text in candidates:
        try:
            btn = page.get_by_text(text, exact=False).first
            if btn.is_visible(timeout=1500):
                btn.click(timeout=1500)
                page.wait_for_timeout(500)
                return True
        except Exception:
            continue
    return False


def get_campaign_links(page):
    page.goto(CAMPAIGNS_URL, wait_until="networkidle", timeout=30000)
    dismiss_cookie_banner(page)
    hrefs = page.eval_on_selector_all(
        "a[href*='/da/campaign/']",
        "els => els.map(e => e.href)",
    )
    # Dedupe while preserving order
    seen = set()
    out = []
    for h in hrefs:
        if h not in seen:
            seen.add(h)
            out.append(h)
    return out[:MAX_CAMPAIGNS]


def extract_deals(page):
    """Runs entirely in-page JS: finds price-looking text nodes, then
    walks up to the nearest ancestor that also has a heading/title/
    link, and returns (deals, raw_price_hits) — raw_price_hits lets
    the caller tell "no prices on this page at all" apart from "found
    prices but couldn't pair them with a name"."""
    js = r"""
    (priceRegexSource) => {
        const priceRe = new RegExp(priceRegexSource, "i");
        const results = [];
        const seen = new Set();
        let rawHits = 0;

        function looksLikeName(text) {
            const t = text.trim();
            const blocklist = [
                "varenummer", "klik for at kopiere", "skarp pris",
                "ekskl. moms", "på lager", "på fjernlager", "på vej ind",
                "levering", "se produkt", "læg i kurv", "produktdatablad",
                "ai-genereret produktdata",
            ];
            const lower = t.toLowerCase();
            if (blocklist.some(b => lower === b || lower.startsWith(b))) return false;
            // Short badge-style labels: "3 års garanti", "OBS: ...",
            // "Max 24 stk pr. kunde", "300 m²" etc. Real product names
            // run much longer, so anything short and badge-shaped is
            // filtered rather than trying to enumerate every badge text.
            if (t.length < 25 && /^(obs:|max\s|\d+\s*m[²2]|\d+\s*års?\s)/i.test(lower)) return false;
            return t.length > 3 && t.length < 200 && !priceRe.test(t);
        }

        function findName(el) {
            let node = el;
            let best = null;
            for (let i = 0; i < 6 && node; i++) {
                const candidates = node.querySelectorAll &&
                    node.querySelectorAll("h1,h2,h3,h4,a,img[alt]");
                if (candidates) {
                    for (const c of candidates) {
                        const t = c.getAttribute("title") ||
                                  c.getAttribute("alt") ||
                                  c.textContent;
                        if (t && looksLikeName(t)) {
                            const trimmed = t.trim();
                            if (!best || trimmed.length > best.length) best = trimmed;
                        }
                    }
                }
                if (best) return best;
                node = node.parentElement;
            }
            return best;
        }

        const walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null
        );
        let n;
        while ((n = walker.nextNode())) {
            const text = n.nodeValue.trim();
            if (!text || !priceRe.test(text)) continue;
            const match = text.match(priceRe);
            if (!match) continue;
            rawHits++;

            const container = n.parentElement && n.parentElement.closest(
                "li,article,div"
            );
            if (!container) continue;

            const name = findName(container);
            if (!name) continue;

            const key = name + "|" + match[0];
            if (seen.has(key)) continue;
            seen.add(key);

            results.push({ name: name, price: match[0].trim() });
        }
        return { deals: results, rawHits: rawHits };
    }
    """
    out = page.evaluate(js, PRICE_RE.pattern)
    return out["deals"], out["rawHits"]


def main():
    print("Ostrich spejder over compumail.dk's kampagner...")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1366, "height": 900},
            locale="da-DK",
        )
        page = context.new_page()

        try:
            campaign_urls = get_campaign_links(page)
        except Exception as e:
            print(f"Kunne ikke hente kampagnelisten: {e}")
            browser.close()
            return

        if not campaign_urls:
            print("Fandt ingen kampagne-links på /da/campaigns.")
            browser.close()
            return

        print(f"Fandt {len(campaign_urls)} kampagner (viser op til {MAX_CAMPAIGNS}):\n")

        first = True
        for url in campaign_urls:
            print(f"  {url}")
            try:
                page.goto(url, wait_until="networkidle", timeout=30000)
                dismiss_cookie_banner(page)
                deals, raw_hits = extract_deals(page)
            except Exception as e:
                print(f"    Kunne ikke hente/scanne siden: {e}")
                continue

            if first:
                page.screenshot(path="compumail_debug.png", full_page=True)
                with open("compumail_debug.html", "w", encoding="utf-8") as f:
                    f.write(page.content())
                try:
                    body_text = page.inner_text("body")
                except Exception:
                    body_text = ""
                with open("compumail_debug_text.txt", "w", encoding="utf-8") as f:
                    f.write(body_text)
                print(f"    (Debug: {len(body_text)} tegn synlig tekst gemt i compumail_debug_text.txt)")
                first = False

            if not deals:
                if raw_hits == 0:
                    print("    Ingen prismønstre fundet overhovedet på siden (0 raw hits) — siden viser nok ingen priser her, eller de indlæses efter networkidle.")
                else:
                    print(f"    Fandt {raw_hits} prismønstre, men kunne ikke parre nogen med et produktnavn — DOM-strukturen omkring priserne er nok anderledes end forventet.")
                continue

            for d in deals[:MAX_DEALS_PER_CAMPAIGN]:
                if FILTER and FILTER not in d['name'].lower():
                    continue
                print(f"    • {d['name']} — {d['price']}")
            print()

        browser.close()


FILTER = sys.argv[1].lower() if len(sys.argv) > 1 else ""


if __name__ == "__main__":
    main()
