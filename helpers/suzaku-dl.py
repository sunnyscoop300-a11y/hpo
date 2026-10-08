#!/usr/bin/env python3
"""Suzaku - Suno song downloader for hpo (fire bird that fetches songs from the cloud)."""
import sys, os, re, subprocess, urllib.request, urllib.error

OUTDIR_DEFAULT = os.path.expanduser("~/Music/suno")
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)


def die(msg):
    print(f"SUZAKU_ERROR: {msg}")
    sys.exit(1)


def extract_id(arg):
    """Extract song UUID from a Suno URL or raw UUID."""
    m = UUID_RE.search(arg)
    if m:
        return m.group(0).lower()
    die(f"could not find a song ID in: {arg}")


def download_mp4(song_id, outdir):
    url = f"https://cdn1.suno.ai/{song_id}.mp4"
    mp4_path = os.path.join(outdir, f"{song_id}.mp4")
    print(f"SUZAKU: fetching {url}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 Suzaku/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            total = int(resp.headers.get("Content-Length", 0))
            with open(mp4_path, "wb") as f:
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
        return mp4_path
    except urllib.error.HTTPError as e:
        die(f"HTTP {e.code} fetching MP4 - song may not be public")
    except Exception as e:
        die(f"download failed: {e}")


def extract_audio(mp4_path, mp3_path):
    print(f"SUZAKU: extracting audio with ffmpeg...")
    cmd = ["ffmpeg", "-y", "-i", mp4_path, "-vn", "-acodec", "libmp3lame",
           "-b:a", "320k", "-loglevel", "error", mp3_path]
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

    mp4_path = download_mp4(song_id, outdir)
    mp3_path = os.path.join(outdir, f"suno-{song_id}.mp3")
    extract_audio(mp4_path, mp3_path)

    # Clean up the MP4 (we only wanted the audio)
    os.remove(mp4_path)

    print(f"SUZAKU_OK: saved {mp3_path}")


if __name__ == "__main__":
    main()
