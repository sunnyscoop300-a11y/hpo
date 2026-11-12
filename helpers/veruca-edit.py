#!/usr/bin/env python3
"""
Veruca edit mode helper (used by Veruca v2's REDIGER mode).

Sends the picture, a copy with the area to edit marked in red and any
reference pictures to the image model as input_references, and saves the
picture that comes back. Veruca v2 then pastes ONLY the marked area into the
original, so the rest of the picture is never changed.

Uses the same config as veruca-gen.py (~/.config/hpo/veruca.conf, provider
openai_compat).

Usage:
  veruca-edit.py input.png marked.png out.png "prompt" strength [ref ...]
strength is 0..100.
Prints VERUCA_OK: saved <file> or VERUCA_ERROR: <why>.
"""

import os, sys, json, time, zlib, struct, base64, importlib.util

# Reuse the config and HTTP code from veruca-gen.py.
_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("veruca_gen", os.path.join(_here, "veruca-gen.py"))
vg = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vg)


def png_bytes_small(path):
    """Veruca v2 saves PNGs without compression. Squeeze them with zlib
    before upload so the request stays small. Any PNG works."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return data
    pos, ihdr, idat, other = 8, None, b"", []
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            ihdr = body
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        else:
            other.append((kind, body))
    if ihdr is None or not idat:
        return data
    try:
        raw = zlib.decompress(idat)
    except zlib.error:
        return data

    def chunk(kind, body):
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff))

    out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
    for kind, body in other:
        out += chunk(kind, body)
    return out + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def data_url(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".png":
        return "data:image/png;base64," + base64.b64encode(png_bytes_small(path)).decode()
    mime = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}.get(ext, "image/png")
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def pick_size(w, h):
    # Same shape as the picture, long side 1536, multiples of 16.
    r = max(1 / 3, min(3, w / h))
    if r >= 1:
        W, H = 1536, 1536 / r
    else:
        W, H = 1536 * r, 1536
    return f"{int(round(W / 16)) * 16}x{int(round(H / 16)) * 16}"


def strength_words(s):
    if s <= 25:
        return "Make only small, subtle changes: details and colours."
    if s <= 50:
        return "Change clothing, accessories or small objects as described."
    if s <= 75:
        return "Replace larger objects as described."
    return "Transform the highlighted area completely as described."


def main():
    if len(sys.argv) < 6:
        vg.die('usage: veruca-edit.py input.png marked.png out.png "prompt" strength [ref ...]')
    inp, marked, out, prompt, strength = sys.argv[1:6]
    refs = [os.path.expanduser(r) for r in sys.argv[6:] if r.strip()]
    for r in refs:
        if not os.path.exists(r):
            vg.die(f"reference not found: {r}")
    s = int(float(strength))

    provider, key, model, endpoint = vg.load_conf()
    if provider != "openai_compat":
        vg.die("edit mode needs provider = openai_compat in veruca.conf")
    url = endpoint or "https://api.openai.com/v1/images/generations"

    use_mark = marked != "-"
    if use_mark:
        text = ("Image 1 is the original picture. Image 2 is the same picture with the area "
                "to edit highlighted in red. "
                f"Edit ONLY the highlighted area: {prompt}. {strength_words(s)} "
                "Keep everything outside the highlighted area exactly as in image 1: the same "
                "composition, framing, lighting, characters, colours and text. "
                "The result must not contain any red highlight.")
        first = 3
    else:
        text = ("Image 1 is the original picture. "
                f"Edit this picture: {prompt}. {strength_words(s)} "
                "Change ONLY what the instruction asks for. Keep everything else exactly as "
                "in image 1: the same characters, their looks, positions and proportions, the "
                "background, all text and typography, lighting, colours, camera angle and "
                "composition. Do not move features from one character to another. "
                "Edit the input picture - do not create a new scene.")
        first = 2
    if refs:
        text += (f" Images {first} to {first + len(refs) - 1} are references: use them to keep "
                 "character identity, outfits and art style.")

    w, h = png_size(inp)
    payload = {
        "prompt": text,
        "n": 1,
        "size": pick_size(w, h),
        "output_format": "png",
        "input_references": [
            {"type": "image_url", "image_url": {"url": data_url(p)}}
            for p in [inp] + ([marked] if use_mark else []) + refs
        ],
    }
    if model:
        payload["model"] = model
    hdr = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

    print("[VERUCA] Sender billedet og markeringen...", flush=True)
    # OpenAI sometimes fails with 502/503/504 - wait and try again.
    for attempt in range(4):
        status, body = vg.http_json(url, payload, hdr)
        if status not in (502, 503, 504) or attempt == 3:
            break
        print(f"[VERUCA] OpenAI svarede {status}, proever igen om {10 * (attempt + 1)} sek...", flush=True)
        time.sleep(10 * (attempt + 1))
    if status != 200:
        vg.die(f"edit failed ({status}): {body[:300].decode(errors='replace')}")

    item = json.loads(body).get("data", [{}])[0]
    if "b64_json" in item:
        raw = base64.b64decode(item["b64_json"])
    elif "url" in item:
        st, raw = vg.http_get(item["url"])
        if st != 200:
            vg.die("could not download the edited picture")
    else:
        vg.die("no picture in the answer")

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "wb") as f:
        f.write(raw)
    print(f"VERUCA_OK: saved {out}", flush=True)


if __name__ == "__main__":
    main()
