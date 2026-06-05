#!/usr/bin/env python3
"""hpo piyoko recipe fetcher - henter en rigtig opskrift fra TheMealDB"""
import json, sys, urllib.request, urllib.parse

# Map Rooster Fighter dish index -> TheMealDB search keyword
KEYWORDS = {
    0: "sushi",        # Sea Urchin Delight
    1: "tempura",      # Crispy Stink Bug Tempura
    2: "skewers",      # Brazilian Grasshopper Skewers
    3: "omelette",     # Golden Egg Omelette
    4: "salad",        # Worm & Seed Trail Mix
    5: "ramen",        # Demon-Slayer Spicy Ramen
    6: "rice",         # Righteous Rice Balls
    7: "dumplings",    # Duty Dumplings
}

def main():
    if len(sys.argv) < 2:
        print("Usage: piyoko-recipe.py <index>", file=sys.stderr)
        sys.exit(1)
    try:
        idx = int(sys.argv[1])
    except ValueError:
        print("[PIYOKO] Invalid recipe index", file=sys.stderr)
        sys.exit(1)

    kw = KEYWORDS.get(idx, "chicken")
    url = "https://www.themealdb.com/api/json/v1/1/search.php?s=" + urllib.parse.quote(kw)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "hpo-piyoko/1.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read())
    except Exception as e:
        print(f"[PIYOKO] Could not fetch recipe: {e}", file=sys.stderr)
        sys.exit(2)

    meals = data.get("meals")
    if not meals:
        print(f"[PIYOKO] No online recipe found for '{kw}'", file=sys.stderr)
        sys.exit(2)

    m = meals[0]
    print(f"  Real-world inspiration: {m.get('strMeal','?')}")
    cat = m.get("strCategory", "")
    area = m.get("strArea", "")
    if cat or area:
        print(f"  ({area} {cat})".strip())
    print()
    print("  Ingredients:")
    for i in range(1, 21):
        ing = m.get(f"strIngredient{i}", "")
        meas = m.get(f"strMeasure{i}", "")
        if ing and ing.strip():
            print(f"    - {meas.strip()} {ing.strip()}".rstrip())
    print()
    instr = m.get("strInstructions", "").strip()
    # Print first ~3 sentences to keep it short
    sentences = instr.replace("\r\n", " ").split(". ")
    short = ". ".join(sentences[:4]).strip()
    if short and not short.endswith("."):
        short += "."
    print("  Method:")
    print(f"    {short}")
    yt = m.get("strYoutube", "")
    if yt:
        print()
        print(f"  Video: {yt}")

if __name__ == "__main__":
    main()
