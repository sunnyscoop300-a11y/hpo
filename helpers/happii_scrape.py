#!/usr/bin/env python3
"""
happii_scrape.py — fallback scraper for happii.dk using a real
(headless) Chromium via Playwright, since happii.dk sits behind
Cloudflare bot protection that silently serves a stripped-down HTML
shell to curl (even with a spoofed browser User-Agent) — no visible
"Just a moment" challenge, just quietly less content. csmegastore.dk
and (hopefully) compumail.dk don't need this; only happii.dk does.

Setup (one-time):
    pip install playwright --break-system-packages
    playwright install chromium

Run:
    python3 happii_scrape.py

Output: product name + price for each product found in the
"Særligt udvalgt til dig" carousel on the happii.dk front page,
printed as plain text — pipe/parse this from vindhjelm (or anything
else) instead of re-implementing browser automation in Hare.
"""

import sys
import time
import re

FILTER = sys.argv[1].lower() if len(sys.argv) > 1 else ""

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Playwright er ikke installeret. Kør:")
    print("  pip install playwright --break-system-packages")
    print("  playwright install chromium")
    sys.exit(1)

URL = "https://www.happii.dk/"

# Matches vindhjelm's own extraction logic (see scan.ha's
# extract_deals_happii): product name lives in a title="" attribute
# on an <a> inside an <h3 class="slide-text__header">, price is in a
# span with class "... slide-currency-attention fw700".
NAME_SELECTOR = "h3.slide-text__header a"
PRICE_SELECTOR = "li.splide__slide"


def scrape():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # A realistic UA + viewport helps somewhat against fingerprinting,
        # though Cloudflare's bot management looks at more than this —
        # there's no guarantee this clears it either, but a full browser
        # engine clears far more bot checks than curl ever will.
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1366, "height": 900},
            locale="da-DK",
        )
        page = context.new_page()
        page.goto(URL, wait_until="networkidle", timeout=30000)

        # Give the Vue components a moment to hydrate + populate the
        # carousel beyond what "networkidle" alone guarantees.
        try:
            page.wait_for_selector(NAME_SELECTOR, timeout=10000)
        except Exception:
            print("Fandt ingen produkter — siden blokerede muligvis stadig,")
            print("eller markørerne har ændret sig. Gemmer et screenshot")
            print("til happii_debug.png så du kan se hvad der faktisk kom.")
            page.screenshot(path="happii_debug.png", full_page=True)
            browser.close()
            return []

        results = []
        slides = page.query_selector_all(PRICE_SELECTOR)
        for slide in slides:
            name_el = slide.query_selector(NAME_SELECTOR)
            if not name_el:
                continue
            name = (name_el.get_attribute("title") or name_el.inner_text() or "").strip()
            if not name:
                continue

            price_el = slide.query_selector("span.slide-currency-attention")
            price = price_el.inner_text().strip() if price_el else ""

            results.append((name, price))

        browser.close()
        return results


def main():
    print("Ostrich flyver forbi Cloudflare med en rigtig browsermotor...")
    deals = scrape()
    if not deals:
        return
    print(f"-> {len(deals)} produkter fundet hos happii.dk:")
    for name, price in deals:
        if price:
            if FILTER and FILTER not in name.lower():
                continue
            print(f"   • {name} — {price}")
        else:
            if FILTER and FILTER not in name.lower():
                continue
            print(f"   • {name}")


if __name__ == "__main__":
    main()
