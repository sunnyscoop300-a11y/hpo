#!/usr/bin/env python3
"""hpo shifu events helper - henter dagens program fra ebillet.dk"""
import json
import sys
import os
import urllib.request
import time
from datetime import datetime, date

CACHE_DIR = os.path.expanduser("~/.cache/hpo")
EVENTS_CACHE = os.path.join(CACHE_DIR, "events.json")
EVENTS_TTL = 6 * 3600  # 6 timer
EVENTS_URL = ("https://bio.ebillet.dk/systemnative/export.asmx/GetEventsALLJson"
              "?Key=RGVubmUgdG9rZW4gZ2l2ZXIgYWRnYW5nIHRpbCBhbGxlIGZvcmVzdGlsbGluZ2Vy"
              "&Debug=0&ForceLoad=0&prettyJSON=0&GetCasheLoadTimes=0&movieId=0")

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

def list_today_events(data, org_id):
    """Returner alle events for én biograf i dag, sorteret efter tid"""
    today = date.today().isoformat()
    movies_dict = {m["_no"]: m.get("name", "?") for m in data["movies"]}
    events = []
    for ev in data["events"]:
        if ev.get("_organizerNo") != org_id:
            continue
        dt = ev.get("dateTime", "")
        if not dt.startswith(today):
            continue
        time_str = dt[11:16]
        movie_name = movies_dict.get(ev.get("_movieNo"), "Unknown")
        events.append((time_str, movie_name))
    events.sort()
    return events

def main():
    if len(sys.argv) < 2:
        print("Usage: shifu-events.py <cinema-query>")
        sys.exit(1)
    query = " ".join(sys.argv[1:])
    data = fetch_events()
    matches = find_org(data, query)
    if not matches:
        print(f"[SHIFU] No cinema found matching '{query}'", file=sys.stderr)
        sys.exit(2)
    # Tag første match (eller hvis flere: vis alle navne)
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
    events = list_today_events(data, org["_no"])
    if not events:
        print(f"  No showings today ({date.today().strftime('%A %d %b %Y')})")
        return
    print(f"  Today, {date.today().strftime('%A %d %b %Y')}:")
    print()
    for time_str, movie in events:
        print(f"  🎬  {time_str}  {movie}")

if __name__ == "__main__":
    main()
