#!/usr/bin/env python3
"""hpo shifu events helper - henter dagens program fra ebillet.dk"""
import json
import sys
import os
import urllib.request
import time
from datetime import datetime, date, timedelta

CACHE_DIR = os.path.expanduser("~/.cache/hpo")
EVENTS_CACHE = os.path.join(CACHE_DIR, "events.json")
EVENTS_TTL = 6 * 3600  # 6 timer
EVENTS_URL = ("https://bio.ebillet.dk/systemnative/export.asmx/GetEventsALLJson"
              "?Key=RGVubmUgdG9rZW4gZ2l2ZXIgYWRnYW5nIHRpbCBhbGxlIGZvcmVzdGlsbGluZ2Vy"
              "&Debug=0&ForceLoad=0&prettyJSON=0&GetCasheLoadTimes=0&movieId=0")

# Danske og engelske dagnavne -> weekday number (Monday=0)
DAY_NAMES = {
    "mandag": 0, "monday": 0, "man": 0, "mon": 0,
    "tirsdag": 1, "tuesday": 1, "tir": 1, "tue": 1,
    "onsdag": 2, "wednesday": 2, "ons": 2, "wed": 2,
    "torsdag": 3, "thursday": 3, "tor": 3, "thu": 3,
    "fredag": 4, "friday": 4, "fre": 4, "fri": 4,
    "lørdag": 5, "loerdag": 5, "saturday": 5, "lør": 5, "sat": 5,
    "søndag": 6, "soendag": 6, "sunday": 6, "søn": 6, "sun": 6,
    "idag": -1, "today": -1, "imorgen": -2, "tomorrow": -2,
}

def parse_day_arg(arg):
    """Returner liste af datoer at vise (idag, eller en specifik weekday)"""
    if not arg:
        return [date.today()]
    a = arg.lower()
    if a in ("uge", "week", "alle", "all"):
        return [date.today() + timedelta(days=i) for i in range(7)]
    if a in ("weekend", "wknd"):
        # Find næste lørdag og søndag
        today = date.today()
        days_until_sat = (5 - today.weekday()) % 7
        sat = today + timedelta(days=days_until_sat)
        sun = sat + timedelta(days=1)
        return [sat, sun]
    if a in DAY_NAMES:
        wd = DAY_NAMES[a]
        if wd == -1:
            return [date.today()]
        if wd == -2:
            return [date.today() + timedelta(days=1)]
        # Find næste forekomst af denne weekday (inkl. idag)
        today = date.today()
        days_ahead = (wd - today.weekday()) % 7
        return [today + timedelta(days=days_ahead)]
    return [date.today()]

def fetch_events():
    os.makedirs(CACHE_DIR, exist_ok=True)
    if os.path.exists(EVENTS_CACHE):
        age = time.time() - os.path.getmtime(EVENTS_CACHE)
        if age < EVENTS_TTL:
            with open(EVENTS_CACHE) as f:
                return json.load(f)
    print("[SHIFU] Fetching cinema data from ebillet.dk...", file=sys.stderr)
    req = urllib.request.Request(EVENTS_URL, headers={"User-Agent": "hpo-shifu/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    with open(EVENTS_CACHE, "w") as f:
        json.dump(data, f)
    return data

def find_org(data, query):
    """Find biograf - ALL words skal matche enten name eller city"""
    words = query.lower().split()
    matches = []
    for org in data["organizers"]:
        haystack = (org.get("name", "") + " " + org.get("city", "")).lower()
        if all(w in haystack for w in words):
            matches.append(org)
    return matches

def list_events_for_day(data, org_id, target_date):
    """Returner alle events for én biograf på en given dato, sorteret efter tid"""
    target_iso = target_date.isoformat()
    movies_dict = {m["_no"]: m.get("name", "?") for m in data["movies"]}
    events = []
    for ev in data["events"]:
        if ev.get("_organizerNo") != org_id:
            continue
        dt = ev.get("dateTime", "")
        if not dt.startswith(target_iso):
            continue
        time_str = dt[11:16]
        movie_name = movies_dict.get(ev.get("_movieNo"), "Unknown")
        events.append((time_str, movie_name))
    events.sort()
    return events

DAY_NAMES_DK = ["Mandag", "Tirsdag", "Onsdag", "Torsdag", "Fredag", "Lørdag", "Søndag"]
MONTH_NAMES_DK = ["januar", "februar", "marts", "april", "maj", "juni",
                  "juli", "august", "september", "oktober", "november", "december"]

def format_date_dk(d):
    return f"{DAY_NAMES_DK[d.weekday()]} {d.day}. {MONTH_NAMES_DK[d.month-1]}"

def main():
    if len(sys.argv) < 2:
        print("Usage: shifu-events.py <cinema-query> [day]")
        print("Days: idag, imorgen, mandag-søndag, weekend, uge")
        sys.exit(1)

    # Separere by-query fra dag-keyword
    args = sys.argv[1:]
    day_arg = None
    if len(args) > 1:
        last = args[-1].lower()
        if last in DAY_NAMES or last in ("uge", "week", "alle", "all", "weekend", "wknd"):
            day_arg = args[-1]
            args = args[:-1]

    query = " ".join(args)
    dates = parse_day_arg(day_arg)

    data = fetch_events()
    matches = find_org(data, query)
    if not matches:
        print(f"[SHIFU] No cinema found matching '{query}'", file=sys.stderr)
        sys.exit(2)
    if len(matches) > 1:
        for org in matches:
            name = org.get("name", "?")
            city = org.get("city", "?")
            print(f"  • {name}, {city}")
        print(f"[SHIFU] Multiple cinemas match '{query}'. Be more specific.", file=sys.stderr)
        sys.exit(2)

    org = matches[0]
    print(f"[SHIFU] {org.get('name')} - {org.get('city')}")
    print()

    any_events = False
    for d in dates:
        events = list_events_for_day(data, org["_no"], d)
        if not events:
            continue
        any_events = True
        print(f"  {format_date_dk(d)}:")
        print()
        for time_str, movie in events:
            print(f"  🎬  {time_str}  {movie}")
        print()

    if not any_events:
        print(f"  No showings found for the requested day(s).")
        sys.exit(2)

if __name__ == "__main__":
    main()
