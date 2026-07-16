#!/usr/bin/env python3
"""
Veruca - generic AI image generator for hpo (Klaus's sister)
Works with multiple API providers via a config file.

Config: ~/.config/hpo/veruca.conf  (INI format, never committed)
  [veruca]
  provider = leonardo        # leonardo | huggingface | stability | openai_compat
  api_key  = YOUR_KEY_HERE
  model    = <optional model id/name for the provider>
  endpoint = <optional override URL for openai_compat>

Usage:
  veruca-gen.py "your image prompt"
  veruca-gen.py "prompt" /path/to/output.png

Output: saved to ~/Pictures/veruca/ by default (or the given path).
Prints one status line prefixed with VERUCA_ for the Hare side to read.
"""

import sys, os, json, time, base64, configparser, urllib.request, urllib.error

CONF = os.path.expanduser("~/.config/hpo/veruca.conf")
OUTDIR = os.path.expanduser("~/Pictures/veruca")


def die(msg):
    print(f"VERUCA_ERROR: {msg}")
    sys.exit(1)


def load_conf():
    if not os.path.exists(CONF):
        die(f"no config at {CONF} - create it with [veruca] provider/api_key")
    cp = configparser.ConfigParser()
    cp.read(CONF)
    if "veruca" not in cp:
        die("config missing [veruca] section")
    s = cp["veruca"]
    prov = s.get("provider", "").strip().lower()
    key = s.get("api_key", "").strip()
    model = s.get("model", "").strip()
    endpoint = s.get("endpoint", "").strip()
    if not prov:
        die("config missing 'provider'")
    if not key:
        die("config missing 'api_key'")
    return prov, key, model, endpoint


def http_json(url, payload, headers, method="POST"):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        die(f"request failed: {e}")


def http_get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        die(f"download failed: {e}")


def save_bytes(raw, outfile):
    os.makedirs(os.path.dirname(outfile), exist_ok=True)
    with open(outfile, "wb") as f:
        f.write(raw)
    print(f"VERUCA_OK: saved {outfile}")


# ---- Provider implementations -------------------------------------------

def gen_leonardo(prompt, key, model, outfile):
    # Leonardo: create generation, then poll for the result
    model_id = model or "b24e16ff-06e3-43eb-8d33-4416c2d75876"  # Leonardo Diffusion XL default
    hdr = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload = {
        "prompt": prompt,
        "modelId": model_id,
        "num_images": 1,
        "width": 1024,
        "height": 1024,
    }
    status, body = http_json("https://cloud.leonardo.ai/api/rest/v1/generations", payload, hdr)
    if status not in (200, 201):
        die(f"leonardo create failed ({status}): {body[:300].decode(errors='replace')}")
    gen_id = json.loads(body).get("sdGenerationJob", {}).get("generationId")
    if not gen_id:
        die("leonardo: no generationId in response")
    # Poll
    for _ in range(40):
        time.sleep(3)
        st, gb = http_get(f"https://cloud.leonardo.ai/api/rest/v1/generations/{gen_id}", hdr)
        if st != 200:
            continue
        gj = json.loads(gb).get("generations_by_pk", {})
        if gj.get("status") == "COMPLETE":
            imgs = gj.get("generated_images", [])
            if not imgs:
                die("leonardo: complete but no images")
            url = imgs[0]["url"]
            ist, iraw = http_get(url)
            if ist != 200:
                die("leonardo: image download failed")
            save_bytes(iraw, outfile)
            return
    die("leonardo: timed out waiting for generation")


def gen_huggingface(prompt, key, model, outfile):
    model_id = model or "black-forest-labs/FLUX.1-schnell"
    url = f"https://api-inference.huggingface.co/models/{model_id}"
    hdr = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    status, body = http_json(url, {"inputs": prompt}, hdr)
    if status != 200:
        die(f"huggingface failed ({status}): {body[:300].decode(errors='replace')}")
    # HF returns raw image bytes
    save_bytes(body, outfile)


def gen_stability(prompt, key, model, outfile):
    # Stability AI - core endpoint returns image bytes
    url = "https://api.stability.ai/v2beta/stable-image/generate/core"
    # multipart/form-data
    boundary = "----verucaboundary"
    parts = []
    for k, v in (("prompt", prompt), ("output_format", "png")):
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n")
    data = ("".join(parts) + f"--{boundary}--\r\n").encode()
    hdr = {
        "Authorization": f"Bearer {key}",
        "Accept": "image/*",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
    }
    req = urllib.request.Request(url, data=data, headers=hdr, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            save_bytes(r.read(), outfile)
    except urllib.error.HTTPError as e:
        die(f"stability failed ({e.code}): {e.read()[:300].decode(errors='replace')}")
    except Exception as e:
        die(f"stability request failed: {e}")


def gen_openai_compat(prompt, key, model, endpoint, outfile):
    # Works with OpenAI-compatible image endpoints (DALL-E style)
    url = endpoint or "https://api.openai.com/v1/images/generations"
    hdr = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    payload = {"prompt": prompt, "n": 1, "size": "1024x1024"}
    if model:
        payload["model"] = model
    status, body = http_json(url, payload, hdr)
    if status != 200:
        die(f"openai_compat failed ({status}): {body[:300].decode(errors='replace')}")
    j = json.loads(body)
    item = j.get("data", [{}])[0]
    if "b64_json" in item:
        save_bytes(base64.b64decode(item["b64_json"]), outfile)
    elif "url" in item:
        ist, iraw = http_get(item["url"])
        if ist != 200:
            die("openai_compat: image download failed")
        save_bytes(iraw, outfile)
    else:
        die("openai_compat: no image in response")


# ---- Main ----------------------------------------------------------------

def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        die('usage: veruca-gen.py "prompt" [output.png]')
    prompt = sys.argv[1]
    if len(sys.argv) >= 3 and sys.argv[2].strip():
        outfile = os.path.expanduser(sys.argv[2])
    else:
        outfile = os.path.join(OUTDIR, f"veruca-{int(time.time())}.png")

    provider, key, model, endpoint = load_conf()

    if provider == "leonardo":
        gen_leonardo(prompt, key, model, outfile)
    elif provider == "huggingface":
        gen_huggingface(prompt, key, model, outfile)
    elif provider == "stability":
        gen_stability(prompt, key, model, outfile)
    elif provider == "openai_compat":
        gen_openai_compat(prompt, key, model, endpoint, outfile)
    else:
        die(f"unknown provider '{provider}' (use: leonardo | huggingface | stability | openai_compat)")


if __name__ == "__main__":
    main()
