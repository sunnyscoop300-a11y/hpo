#!/usr/bin/env python3
"""Suzaku - Suno song downloader for hpo (firebird that fetches songs from the cloud).

Tries several CDN URL patterns and verifies the response is actually audio
before saving. Falls back from direct MP3 to MP4+ffmpeg extraction if needed.
"""
import sys, os, re, subprocess, urllib.request, urllib.error

OUTDIR_DEFAULT = os.path.expanduser("~/Music/suno")
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)

BROWSER_UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")
HEADERS = {"User-Agent": BROWSER_UA, "Referer": "https://suno.com/",
           "Origin": "https://suno.com"}


def die(msg):
    print(f"SUZAKU_ERROR: {msg}")
    sys.exit(1)


def looks_like_audio(head):
    """Check if first bytes look like audio (mp3/mp4/m4a/flac/ogg/wav)."""
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
    # MP3 frame sync
    if head[0] == 0xFF and (head[1] & 0xE0) == 0xE0:
        return True
    return False


def extract_id(arg):
    """Extract song UUID. If it's a /s/<short>-link, follow redirect to /song/<uuid>."""
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
    """GET first 16 bytes; return True if it looks like audio."""
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
    """Try several CDN patterns, return first one that returns audio bytes."""
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

    mp3_path = os.path.join(outdir, f"suno-{song_id}.mp3")

    if kind == "mp3":
        # Direct MP3 - just download it
        download(url, mp3_path)
    else:
        # MP4 - download then extract audio
        mp4_path = os.path.join(outdir, f"{song_id}.mp4")
        download(url, mp4_path)
        extract_audio(mp4_path, mp3_path)
        os.remove(mp4_path)

    print(f"SUZAKU_OK: saved {mp3_path}")


if __name__ == "__main__":
    main()
