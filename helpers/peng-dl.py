#!/usr/bin/env python3
"""Peng - Suno song downloader for hpo (firebird that fetches songs from the cloud).

Tries several CDN URL patterns and verifies the response is actually audio
before saving. Fetches title and artist metadata to name the MP3 nicely.
"""
import sys, os, re, json, subprocess, urllib.request, urllib.error

OUTDIR_DEFAULT = os.path.expanduser("~/Music/suno")
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
TITLE_TAG_RE = re.compile(r"<title>([^<]+)</title>", re.I)

BROWSER_UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")
HEADERS = {"User-Agent": BROWSER_UA, "Referer": "https://suno.com/",
           "Origin": "https://suno.com"}


def die(msg):
    print(f"PENG_ERROR: {msg}")
    sys.exit(1)


def looks_like_audio(head):
    if len(head) < 4:
        return False
    try:
        s = head.decode("latin-1", errors="replace")
    except Exception:
        return False
    if len(head) >= 8 and s[4:8] == "ftyp":
        return True
    if s.startswith(("ID3", "OggS", "fLaC", "RIFF")):
        return True
    if head[0] == 0xFF and (head[1] & 0xE0) == 0xE0:
        return True
    return False


def extract_id(arg):
    m = UUID_RE.search(arg)
    if m:
        return m.group(0).lower()
    if "suno.com/s/" in arg or "suno.ai/s/" in arg:
        print(f"PENG: resolving short link {arg}")
        try:
            req = urllib.request.Request(arg, headers=HEADERS, method="GET")
            with urllib.request.urlopen(req, timeout=15) as resp:
                final_url = resp.geturl()
                m = UUID_RE.search(final_url)
                if m:
                    return m.group(0).lower()
                body = resp.read(100000).decode("utf-8", errors="replace")
                m = re.search(r"/song/" + UUID_RE.pattern, body)
                if m:
                    return UUID_RE.search(m.group(0)).group(0).lower()
        except Exception as e:
            die(f"could not resolve short link: {e}")
    die(f"could not find a song ID in: {arg}")


def try_url(url):
    try:
        req = urllib.request.Request(url, headers={**HEADERS, "Range": "bytes=0-15"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status not in (200, 206):
                return False
            head = resp.read(16)
            return looks_like_audio(head)
    except Exception:
        return False


def find_working_url(song_id):
    candidates = [
        (f"https://cdn1.suno.ai/{song_id}.mp3", "mp3"),
        (f"https://cdn2.suno.ai/{song_id}.mp3", "mp3"),
        (f"https://cdn1.suno.ai/{song_id}.mp4", "mp4"),
        (f"https://audiopipe.suno.ai/?item_id={song_id}", "mp3"),
    ]
    for url, kind in candidates:
        print(f"PENG: testing {url}... ", end="", flush=True)
        if try_url(url):
            print("OK")
            return url, kind
        print("no")
    return None, None


def fetch_json(url, timeout=15):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def fetch_text(url, timeout=15):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def html_unescape(s):
    """Minimal HTML entity decoder for &quot; &amp; &#39; etc."""
    import html
    return html.unescape(s)

# PENG_EXTRA_FIX: strip trailing "quoted extra info" and (prod./written by ...) credits
def clean_title(t):
    s = t.strip()
    for _ in range(3):
        m = re.match(r'^(.*?\S)\s*[\"“]+[^\"“”]*[\"”]+\s*$', s)
        if m:
            s = m.group(1).strip()
            continue
        m = re.match(r'^(.*?\S)\s*[\(\[][^\)\]]*(?:prod|produced|written|feat\.? by|by:)[^\)\]]*[\)\]]\s*$', s, re.I)
        if m:
            s = m.group(1).strip()
            continue
        break
    return s or t

def split_title_artist(raw):
    """Try to pull artist and clean title out of a Suno-style title string.

    Handles patterns like:
      'Jett Ryder - "Old Lovers"'       -> ('Old Lovers',       'Jett Ryder')
      'Chihi - "Boom Like a Monster"'   -> ('Boom Like a Monster', 'Chihi')
      '"Gassy Today" By Artist: Tina T' -> ('Gassy Today',      'Tina T')
      '"Gassy Today" By Tina Tuner'     -> ('Gassy Today',      'Tina Tuner')
      'FakeNews - "Loveberry Riot"'     -> ('Loveberry Riot',   'FakeNews')
    Returns (clean_title, artist) or (raw, None) if no pattern matched.
    """
    s = raw.strip()

    # Pattern A: "<title>" By [Artist:] <artist>
    m = re.match(r'^[\"\u201C](.+?)[\"\u201D]\s*(?:By|by)\s+(?:Artist[:\s]+)?(.+?)\s*$', s)
    if m:
        return m.group(1).strip(), m.group(2).strip()

    # Pattern B: <artist> - "<title>" or <artist> – "<title>"
    # PENG_SEP_FIX: also '.', ':', '|', middle dot as separator, and doubled quotes
    m = re.match(r'^(.+?)\s*[-\u2013\u2014.:|\u00B7]\s*[\"\u201C]+(.+?)[\"\u201D]+\s*$', s)
    if m:
        return m.group(2).strip(), m.group(1).strip()

    # Pattern C: <artist> - <title> (no quotes, use first dash)
    m = re.match(r'^(.+?)\s+[-\u2013\u2014]\s+(.+?)\s*$', s)
    if m:
        return m.group(2).strip(), m.group(1).strip()

    return raw, None

def fetch_metadata(song_id):
    """Return (title, artist) best effort - both may be None."""
    title = artist = None

    # 1. Try clip-API (gives clean title)
    try:
        data = fetch_json(f"https://studio-api.prod.suno.com/api/clip/{song_id}", timeout=10)
        title = data.get("title")
                # display_name from Suno is the profile name (e.g. "Vizi Blink"),
        # not the song's artist. Use it only as fallback.
        profile_name = data.get("display_name") or data.get("handle")
        save_handle(data.get("handle"))
        cover_url = data.get("image_large_url") or data.get("image_url")
    except Exception as e:
        print(f"PENG: clip-api metadata failed ({e}), trying HTML fallback")

    # 2. Scrape HTML <title> as fallback / for artist
    if not title or not artist:
        try:
            html = fetch_text(f"https://suno.com/song/{song_id}")
            m = TITLE_TAG_RE.search(html)
            if m:
                raw = html_unescape(m.group(1)).strip()
                # Format: "<title>" by <artist> | Suno
                raw = re.sub(r"\s*\|\s*Suno\s*$", "", raw)
                parts = re.split(r"\s+by\s+", raw, maxsplit=1)
                if len(parts) == 2:
                    if not title:
                        title = parts[0].strip().strip('"')
                    if not artist:
                        artist = parts[1].strip()
                elif not title:
                    title = raw.strip('"')
        except Exception as e:
            print(f"PENG: HTML metadata failed ({e})")

     # Try to extract real artist from the title (Suno titles often embed it)
    if title:
        extracted_title, extracted_artist = split_title_artist(title)
        if extracted_artist:
            title = extracted_title
            artist = extracted_artist
    if title:
        title = clean_title(title)
    # Fall back to profile name if nothing better found
    if not artist:
        try:
            artist = profile_name
        except NameError:
            pass
    # Also fall back cover_url to None if it was never set
    try:
        _ = cover_url
    except NameError:
        cover_url = None
    return title, artist, cover_url
def sanitize_filename(name):
    """Make a string safe to use as a filename on Linux/macOS/Windows."""
    # Convert curly quotes/apostrophes to straight ones first
    name = name.replace("\u2018", "'").replace("\u2019", "'").replace("\u201C", '"').replace("\u201D", '"')
    # Remove straight quotes and colons entirely (apostrophes stay)
    name = re.sub(r'["\:]', "", name)
    # Replace other illegal chars with underscore
    name = re.sub(r'[/\\*?<>|]', "_", name)
    # Collapse whitespace
    name = re.sub(r"\s+", " ", name).strip()
    # Avoid leading dot (hidden file) and trailing dots/spaces (Windows)
    name = name.lstrip(".").rstrip(". ")
    # Reasonable length limit
    if len(name) > 180:
        name = name[:180].rstrip()
    return name or "untitled"


def build_filename(title, artist, song_id):
    if title and artist:
        return f"{sanitize_filename(artist)} - {sanitize_filename(title)}.mp3"
    if title:
        return f"{sanitize_filename(title)}.mp3"
    return f"suno-{song_id}.mp3"


def download(url, outpath):
    print(f"PENG: downloading {url}")
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        with open(outpath, "wb") as f:
            downloaded = 0
            while True:
                chunk = resp.read(65536)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                if total:
                    pct = int(downloaded * 100 / total)
                    print(f"\rPENG: downloading... {pct}%", end="", flush=True)
    print()


def extract_audio(src, dst):
    print(f"PENG: extracting audio with ffmpeg...")
    cmd = ["ffmpeg", "-y", "-i", src, "-vn", "-acodec", "libmp3lame",
           "-b:a", "320k", "-loglevel", "error", dst]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        die(f"ffmpeg failed: {result.stderr}")


def extract_audio_with_cover(src, dst, cover_path, title, artist):
    """Extract audio from MP4 to MP3, embedding cover + metadata if given."""
    print(f"PENG: extracting audio with ffmpeg...")
    cmd = ["ffmpeg", "-y", "-i", src]
    if cover_path:
        cmd += ["-i", cover_path]
    cmd += ["-map", "0:a"]
    if cover_path:
        cmd += ["-map", "1:v", "-c:v", "mjpeg",
                "-metadata:s:v", "title=Album cover",
                "-metadata:s:v", "comment=Cover (front)",
                "-disposition:v", "attached_pic"]
    cmd += ["-c:a", "libmp3lame", "-b:a", "320k", "-id3v2_version", "3"]
    if title:
        cmd += ["-metadata", f"title={title}"]
    if artist:
        cmd += ["-metadata", f"artist={artist}"]
    cmd += ["-metadata", "album=Suno", "-loglevel", "error", dst]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        die(f"ffmpeg failed: {result.stderr}")


def embed_cover(mp3_path, cover_path, title, artist):
    """Re-mux an existing MP3 to add cover art and metadata."""
    print(f"PENG: embedding cover art...")
    tmp_path = mp3_path + ".tmp.mp3"
    cmd = ["ffmpeg", "-y", "-i", mp3_path, "-i", cover_path,
           "-map", "0:a", "-map", "1:v",
           "-c:a", "copy", "-c:v", "mjpeg",
           "-metadata:s:v", "title=Album cover",
           "-metadata:s:v", "comment=Cover (front)",
           "-disposition:v", "attached_pic",
           "-id3v2_version", "3"]
    if title:
        cmd += ["-metadata", f"title={title}"]
    if artist:
        cmd += ["-metadata", f"artist={artist}"]
    cmd += ["-metadata", "album=Suno", "-loglevel", "error", tmp_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"PENG: cover embed failed ({result.stderr.strip()}), keeping MP3 without cover")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return
    os.replace(tmp_path, mp3_path)



# PENG_SEARCH: find songs by name
CONF_DIR = os.path.expanduser("~/.config/hpo")
HANDLE_FILE = os.path.join(CONF_DIR, "peng_handle.txt")
INDEX_FILE = os.path.join(CONF_DIR, "peng_index.txt")


def _norm(s):
    s = s.lower().replace("“", " ").replace("”", " ")
    return " ".join(re.sub(r"[^\w\s]", " ", s).split())


def save_handle(handle):
    if not handle:
        return
    try:
        os.makedirs(CONF_DIR, exist_ok=True)
        if not os.path.exists(HANDLE_FILE):
            with open(HANDLE_FILE, "w") as f:
                f.write(handle.strip() + "\n")
            print(f"PENG: remembered your Suno handle '{handle}' for name search")
    except Exception:
        pass


def add_to_index(song_id, label):
    try:
        os.makedirs(CONF_DIR, exist_ok=True)
        if os.path.exists(INDEX_FILE):
            with open(INDEX_FILE) as f:
                if any(l.startswith(song_id + "|") for l in f):
                    return
        with open(INDEX_FILE, "a") as f:
            f.write(f"{song_id}|{label}\n")
    except Exception:
        pass


def profile_clips(handle, max_pages=25):
    clips = []
    for page in range(1, max_pages + 1):
        url = (f"https://studio-api.prod.suno.com/api/profiles/{handle}"
               f"?page={page}&playlists_sort_by=created_at&clips_sort_by=created_at")
        try:
            data = fetch_json(url, timeout=15)
        except Exception as e:
            if page == 1:
                print(f"PENG: could not read Suno profile '{handle}' ({e})")
            break
        batch = data.get("clips") or []
        if not batch:
            break
        for c in batch:
            if c.get("id") and c.get("title"):
                clips.append((c["id"], c["title"]))
    return clips


def index_clips():
    out = []
    try:
        with open(INDEX_FILE) as f:
            for line in f:
                if "|" in line:
                    sid, label = line.rstrip("\n").split("|", 1)
                    out.append((sid, label))
    except FileNotFoundError:
        pass
    return out


def resolve_by_name(query):
    words = _norm(query).split()
    if not words:
        die("empty song name")
    handle = None
    try:
        with open(HANDLE_FILE) as f:
            handle = f.read().strip() or None
    except FileNotFoundError:
        pass

    print(f"PENG: searching for \"{query}\"...")
    seen, matches = set(), []
    pool = (profile_clips(handle) if handle else []) + index_clips()
    for sid, title in pool:
        if sid in seen:
            continue
        seen.add(sid)
        if all(w in _norm(title) for w in words):
            matches.append((sid, title))

    if not matches:
        if not handle:
            die("no match. Download one of your songs by URL once so Peng learns "
                "your Suno handle, or write it in ~/.config/hpo/peng_handle.txt")
        die(f"no song matching \"{query}\" (searched profile '{handle}' and Peng's list)")
    if len(matches) == 1:
        print(f"PENG: found {matches[0][1]}")
        return matches[0][0]

    print(f"PENG: {len(matches)} songs match:")
    for i, (sid, title) in enumerate(matches[:20], 1):
        print(f"   {i:2}. {title}")
    if not sys.stdin.isatty():
        print("PENG: taking number 1 (no terminal to ask in)")
        return matches[0][0]
    while True:
        try:
            pick = input("PENG: which one? [1] ").strip() or "1"
        except EOFError:
            pick = "1"
        if pick.isdigit() and 1 <= int(pick) <= min(len(matches), 20):
            return matches[int(pick) - 1][0]
        print("PENG: type a number from the list")


def looks_like_name(arg):
    return not UUID_RE.search(arg) and "suno." not in arg and "://" not in arg


def main():
    if len(sys.argv) < 2:
        die("usage: peng-dl.py <suno-url | song-id | \"song name\"> [output-dir]")
    arg = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else OUTDIR_DEFAULT
    os.makedirs(outdir, exist_ok=True)

    song_id = resolve_by_name(arg) if looks_like_name(arg) else extract_id(arg)
    print(f"PENG: song ID = {song_id}")

    url, kind = find_working_url(song_id)
    if url is None:
        die(f"no working audio URL found for {song_id} - song may be private or Suno may have changed their CDN")

    title, artist, cover_url = fetch_metadata(song_id)




    if title or artist:
        print(f"PENG: {artist or '?'} - {title or '?'}")

    filename = build_filename(title, artist, song_id)
    mp3_path = os.path.join(outdir, filename)

    # Download cover art for embedding (optional)
    cover_path = None
    if cover_url:
        try:
            cover_path = os.path.join(outdir, f".{song_id}.cover.jpg")
            print(f"PENG: fetching cover art")
            download(cover_url, cover_path)
        except Exception as e:
            print(f"PENG: cover fetch failed ({e}), skipping embed")
            cover_path = None

    if kind == "mp3":
        download(url, mp3_path)
        if cover_path:
            embed_cover(mp3_path, cover_path, title, artist)
    else:
        mp4_path = os.path.join(outdir, f".{song_id}.tmp.mp4")
        download(url, mp4_path)
        extract_audio_with_cover(mp4_path, mp3_path, cover_path, title, artist)
        os.remove(mp4_path)

    if cover_path and os.path.exists(cover_path):
        os.remove(cover_path)

    add_to_index(song_id, os.path.basename(mp3_path)[:-4])
    print(f"PENG_OK: saved {mp3_path}")


if __name__ == "__main__":
    main()
