#!/usr/bin/env python3
"""hpo piyoko recipe fetcher - henter en rigtig opskrift fra TheMealDB.
Med --pdf laver den en paen Piyoko-tematiseret PDF i ~/Downloads."""
import json, sys, os, urllib.request, urllib.parse

KEYWORDS = {
    0: "sushi", 1: "tempura", 2: "skewers", 3: "omelette",
    4: "salad", 5: "ramen", 6: "rice", 7: "dumplings",
}
PIYOKO_NAMES = {
    0: "Sea Urchin Delight", 1: "Crispy Stink Bug Tempura",
    2: "Brazilian Grasshopper Skewers", 3: "Golden Egg Omelette",
    4: "Worm & Seed Trail Mix", 5: "Demon-Slayer Spicy Ramen",
    6: "Righteous Rice Balls", 7: "Duty Dumplings",
}


def fetch(idx):
    kw = KEYWORDS.get(idx, "chicken")
    url = "https://www.themealdb.com/api/json/v1/1/search.php?s=" + urllib.parse.quote(kw)
    req = urllib.request.Request(url, headers={"User-Agent": "hpo-piyoko/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.loads(r.read())
    meals = data.get("meals")
    if not meals:
        return None
    return meals[0]


def get_ingredients(m):
    out = []
    for i in range(1, 21):
        ing = m.get(f"strIngredient{i}") or ""
        meas = m.get(f"strMeasure{i}") or ""
        if ing.strip():
            out.append(f"{meas.strip()} {ing.strip()}".strip())
    return out


def print_text(idx, m):
    print(f"  Real-world inspiration: {m.get('strMeal', '?')}")
    cat = m.get("strCategory") or ""
    area = m.get("strArea") or ""
    if cat or area:
        print(f"  ({area} {cat})".strip())
    print()
    print("  Ingredients:")
    for ing in get_ingredients(m):
        print(f"    - {ing}")
    print()
    instr = str(m.get("strInstructions") or "").strip()
    sentences = instr.replace("\r\n", " ").split(". ")
    short = ". ".join(sentences[:4]).strip()
    if short and not short.endswith("."):
        short += "."
    print("  Method:")
    print(f"    {short}")
    yt = m.get("strYoutube") or ""
    if yt:
        print()
        print(f"  Video: {yt}")


def make_pdf(idx, m):
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.lib import colors
    from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                    TableStyle, HRFlowable, ListFlowable, ListItem)
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.enums import TA_CENTER
    import html as _html

    GOLD = colors.HexColor("#E8A317")
    DARKGOLD = colors.HexColor("#B8860B")
    CREAM = colors.HexColor("#FFF8E7")
    BROWN = colors.HexColor("#5C4033")

    piyoko_name = PIYOKO_NAMES.get(idx, "Piyoko Recipe")
    real = m.get("strMeal") or "?"
    safe = "".join(c if c.isalnum() else "-" for c in piyoko_name).strip("-").lower()
    outdir = os.path.join(os.path.expanduser("~"), "Downloads")
    os.makedirs(outdir, exist_ok=True)
    outpath = os.path.join(outdir, f"piyoko-{safe}.pdf")

    doc = SimpleDocTemplate(outpath, pagesize=A4, topMargin=18*mm,
                            bottomMargin=18*mm, leftMargin=20*mm, rightMargin=20*mm)
    styles = getSampleStyleSheet()

    def st(name, **kw):
        return ParagraphStyle(name, parent=styles['Normal'], **kw)

    title_s = st('T', fontSize=26, textColor=DARKGOLD, alignment=TA_CENTER, fontName='Helvetica-Bold', spaceAfter=2)
    sub_s = st('S', fontSize=11, textColor=BROWN, alignment=TA_CENTER, fontName='Helvetica-Oblique', spaceAfter=2)
    ban_s = st('B', fontSize=10, textColor=colors.white, alignment=TA_CENTER, fontName='Helvetica-Bold')
    h2_s = st('H2', fontSize=14, textColor=DARKGOLD, fontName='Helvetica-Bold', spaceBefore=10, spaceAfter=6)
    body_s = st('Body', fontSize=10.5, textColor=BROWN, leading=15, spaceAfter=3)
    meta_s = st('M', fontSize=9.5, textColor=BROWN, alignment=TA_CENTER)

    def esc(t):
        return _html.escape(str(t or ""))

    story = []
    story.append(Paragraph("PIYOKO'S KOKKEBOG", sub_s))
    story.append(Spacer(1, 2))
    story.append(Paragraph(esc(piyoko_name), title_s))
    story.append(Paragraph(f"~ inspireret af {esc(real)} ~", sub_s))
    story.append(Spacer(1, 6))

    banner = Table([[Paragraph("&#127844;  Each fold made with DUTY!  &#127844;", ban_s)]], colWidths=[170*mm])
    banner.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), GOLD),
        ('TOPPADDING', (0, 0), (-1, -1), 6), ('BOTTOMPADDING', (0, 0), (-1, -1), 6)]))
    story.append(banner)
    story.append(Spacer(1, 10))

    cat = m.get("strCategory") or ""
    area = m.get("strArea") or ""
    meta = Table([[Paragraph(f"<b>Ret:</b> {esc(area)} {esc(cat)}", meta_s)]], colWidths=[170*mm])
    meta.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), CREAM),
        ('BOX', (0, 0), (-1, -1), 0.5, GOLD), ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6)]))
    story.append(meta)
    story.append(Spacer(1, 6))
    story.append(HRFlowable(width="100%", thickness=1.5, color=GOLD))

    story.append(Paragraph("Ingredienser", h2_s))
    ings = get_ingredients(m)
    if ings:
        items = [ListItem(Paragraph(esc(i), body_s), leftIndent=6) for i in ings]
        story.append(ListFlowable(items, bulletType='bullet', bulletColor=GOLD, bulletFontSize=8, leftIndent=14))
    else:
        story.append(Paragraph("Ingredienser ikke tilgaengelige.", body_s))
    story.append(Spacer(1, 4))
    story.append(HRFlowable(width="100%", thickness=1.5, color=GOLD))

    story.append(Paragraph("Fremgangsm&aring;de", h2_s))
    instr = str(m.get("strInstructions") or "").replace("\r\n", "\n").strip()
    if instr:
        for para in [pp for pp in instr.split("\n") if pp.strip()]:
            story.append(Paragraph(esc(para.strip()), body_s))
            story.append(Spacer(1, 4))
    else:
        story.append(Paragraph("Se videoen nedenfor for fremgangsm&aring;den.", body_s))

    yt = m.get("strYoutube") or ""
    if yt:
        story.append(Spacer(1, 4))
        story.append(HRFlowable(width="100%", thickness=0.5, color=DARKGOLD))
        story.append(Paragraph(f"&#127909; Video: {esc(yt)}", meta_s))

    story.append(Spacer(1, 10))
    story.append(Paragraph(f"Fra hpo Piyoko's Kokkebog &bull; recipe #{idx} &bull; lavet med DUTY &#128039;",
        st('F', fontSize=8, textColor=BROWN, alignment=TA_CENTER, fontName='Helvetica-Oblique')))
    doc.build(story)
    return outpath


def main():
    args = list(sys.argv[1:])
    want_pdf = "--pdf" in args
    args = [a for a in args if a != "--pdf"]
    if not args:
        print("Usage: piyoko-recipe.py <index> [--pdf]", file=sys.stderr)
        sys.exit(1)
    try:
        idx = int(args[0])
    except ValueError:
        print("[PIYOKO] Invalid recipe index", file=sys.stderr)
        sys.exit(1)

    try:
        m = fetch(idx)
    except Exception as e:
        print(f"[PIYOKO] Could not fetch recipe: {e}", file=sys.stderr)
        sys.exit(2)
    if not m:
        print("[PIYOKO] No online recipe found", file=sys.stderr)
        sys.exit(2)

    if want_pdf:
        try:
            path = make_pdf(idx, m)
            print(f"  [PIYOKO] PDF gemt: {path}")
            print(f"  Print den med: lp \"{path}\"")
        except Exception as e:
            print(f"[PIYOKO] PDF-fejl: {e}", file=sys.stderr)
            sys.exit(3)
    else:
        print_text(idx, m)


if __name__ == "__main__":
    main()
