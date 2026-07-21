#!/usr/bin/env python3
"""Mastodon - AI chat assistant for hpo (shares OpenRouter key with Veruca)."""
import sys, os, json, configparser, urllib.request, urllib.error

CONFDIR = os.path.expanduser("~/.config/hpo")
MASTODON_CONF = os.path.join(CONFDIR, "mastodon.conf")
SHARED_KEY = os.path.join(CONFDIR, "openrouter_key.txt")
VERUCA_CONF = os.path.join(CONFDIR, "veruca.conf")
DEFAULT_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-3.6-flash"
DEFAULT_SYSTEM = "You are Mastodon, a wise, concise and helpful assistant living inside the hpo command-line tool."

def die(msg):
    print(f"MASTODON_ERROR: {msg}"); sys.exit(1)

def read_mastodon_conf():
    if not os.path.exists(MASTODON_CONF): return "", "", "", ""
    cp = configparser.ConfigParser(); cp.read(MASTODON_CONF)
    if "mastodon" not in cp: return "", "", "", ""
    s = cp["mastodon"]
    return (s.get("api_key","").strip(), s.get("model","").strip(),
            s.get("endpoint","").strip(), s.get("system","").strip())

def read_shared_key():
    if os.path.exists(SHARED_KEY):
        try:
            with open(SHARED_KEY) as f: return f.read().strip()
        except Exception: return ""
    return ""

def read_veruca_key():
    if not os.path.exists(VERUCA_CONF): return ""
    cp = configparser.ConfigParser(); cp.read(VERUCA_CONF)
    if "veruca" not in cp: return ""
    v = cp["veruca"]
    prov = v.get("provider","").strip().lower()
    ep = v.get("endpoint","").strip().lower()
    if prov == "openai_compat" or "openrouter" in ep or "openai" in ep:
        return v.get("api_key","").strip()
    return ""

def resolve_config():
    key, model, endpoint, system = read_mastodon_conf()
    if not key: key = read_shared_key()
    if not key: key = read_veruca_key()
    if not key:
        die("no API key. Put it in ~/.config/hpo/openrouter_key.txt (shared with Veruca) or mastodon.conf")
    return (key, model or DEFAULT_MODEL, endpoint or DEFAULT_ENDPOINT, system or DEFAULT_SYSTEM)

def ask(key, model, endpoint, system, question):
    payload = {"model": model, "messages": [
        {"role": "system", "content": system},
        {"role": "user", "content": question}]}
    data = json.dumps(payload).encode()
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json",
               "HTTP-Referer": "https://github.com/sunnyscoop300-a11y/hpo", "X-Title": "hpo-mastodon"}
    req = urllib.request.Request(endpoint, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r: body = r.read()
    except urllib.error.HTTPError as e:
        die(f"request failed ({e.code}): {e.read()[:400].decode(errors='replace')}")
    except Exception as e:
        die(f"request failed: {e}")
    try:
        j = json.loads(body); return j["choices"][0]["message"]["content"].strip()
    except Exception:
        die(f"could not parse response: {body[:400].decode(errors='replace')}")

def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        die('usage: mastodon-chat.py "your question"')
    question = " ".join(sys.argv[1:])
    key, model, endpoint, system = resolve_config()
    print(ask(key, model, endpoint, system, question))

if __name__ == "__main__":
    main()
