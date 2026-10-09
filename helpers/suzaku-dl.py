#!/usr/bin/env python3
"""Suzaku - Suno song downloader for hpo (firebird that fetches songs from the cloud).

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
    print(f"SUZAKU_ERROR: {msg}")
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
        print(f"SUZAKU: resolving short link {arg}")
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
        print(f"SUZAKU: testing {url}... ", end="", flush=True)
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


def fetch_metadata(song_id):
    """Return (title, artist) best effort - both may be None."""
    title = artist = None

    # 1. Try clip-API (gives clean title)
    try:
        data = fetch_json(f"https://studio-api.prod.suno.com/api/clip/{song_id}", timeout=10)
        title = data.get("title")
        # some responses have display_name or handle
        artist = data.get("display_name") or data.get("handle")
    except Exception as e:
        print(f"SUZAKU: clip-api metadata failed ({e}), trying HTML fallback")

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
            print(f"SUZAKU: HTML metadata failed ({e})")

    return title, artist


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
    print(f"SUZAKU: downloading {url}")
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
                    print(f"\rSUZAKU: downloading... {pct}%", end="", flush=True)
    print()


def extract_audio(src, dst):
    print(f"SUZAKU: extracting audio with ffmpeg...")
    cmd = ["ffmpeg", "-y", "-i", src, "-vn", "-acodec", "libmp3lame",
           "-b:a", "320k", "-loglevel", "error", dst]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        die(f"ffmpeg failed: {result.stderr}")


def main():
    if len(sys.argv) < 2:
        die("usage: suzaku-dl.py <suno-url-or-id> [output-dir]")
    arg = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else OUTDIR_DEFAULT
    os.makedirs(outdir, exist_ok=True)

    song_id = extract_id(arg)
    print(f"SUZAKU: song ID = {song_id}")

    url, kind = find_working_url(song_id)
    if url is None:
        die(f"no working audio URL found for {song_id} - song may be private or Suno may have changed their CDN")

    title, artist = fetch_metadata(song_id)
    if title or artist:
        print(f"SUZAKU: {artist or '?'} - {title or '?'}")

    filename = build_filename(title, artist, song_id)
    mp3_path = os.path.join(outdir, filename)

    if kind == "mp3":
        download(url, mp3_path)
    else:
        mp4_path = os.path.join(outdir, f".{song_id}.tmp.mp4")
        download(url, mp4_path)
        extract_audio(mp4_path, mp3_path)
        os.remove(mp4_path)

    print(f"SUZAKU_OK: saved {mp3_path}")


if __name__ == "__main__":
    main()
