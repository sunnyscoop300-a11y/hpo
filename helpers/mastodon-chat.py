#!/usr/bin/env python3
"""
Mastodon - AI chat assistant for hpo (the wise elephant)
Asks a question, gets an answer via an OpenAI-compatible chat endpoint
(default: OpenRouter + Gemini 3.8 Flash).

Config: ~/.config/hpo/mastodon.conf  (INI, never committed)
  [mastodon]
  api_key  = sk-or-...                                  # OpenRouter key (optional, falls back to openrouter_key.txt)
  model    = google/gemini-3.8-flash                    # any chat model
  endpoint = https://openrouter.ai/api/v1/chat/completions
  system   = You are Mastodon, a wise and helpful assistant.  # optional

Shared key fallback: ~/.config/hpo/openrouter_key.txt (shared with Veruca)

Usage:
  mastodon-chat.py "your question here"
  mastodon-chat.py --ling "your question"    # use Ling 3.1 Flash (falls back to default on 429)

Prints the answer to stdout. Errors are prefixed MASTODON_ERROR:.
"""

import sys, os, json, configparser, urllib.request, urllib.error

CONF = os.path.expanduser("~/.config/hpo/mastodon.conf")
SHARED_KEY = os.path.expanduser("~/.config/hpo/openrouter_key.txt")
DEFAULT_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-3.8-flash"
DEFAULT_SYSTEM = "You are Mastodon, a wise, concise and helpful assistant living inside the hpo command-line tool."
LING_MODEL = "inclusionai/ling-3.1-flash"
ARGON_MODEL = "google/gemini-4-argon"
# free 3.1 is often rate-limited -> try paid 3.0 before giving up on Ling
LING_FALLBACK = {"inclusionai/ling-3.1-flash": "inclusionai/ling-3.0-flash"}


def die(msg):
    print(f"MASTODON_ERROR: {msg}")
    sys.exit(1)


def read_shared_key():
    try:
        with open(SHARED_KEY) as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""


def load_conf():
    key = ""
    model = DEFAULT_MODEL
    endpoint = DEFAULT_ENDPOINT
    system = DEFAULT_SYSTEM
    if os.path.exists(CONF):
        cp = configparser.ConfigParser()
        cp.read(CONF)
        if "mastodon" in cp:
            s = cp["mastodon"]
            key = s.get("api_key", "").strip()
            model = s.get("model", "").strip() or DEFAULT_MODEL
            endpoint = s.get("endpoint", "").strip() or DEFAULT_ENDPOINT
            system = s.get("system", "").strip() or DEFAULT_SYSTEM
    if not key:
        key = read_shared_key()
    if not key:
        die(f"no API key. Put it in {SHARED_KEY} (shared with Veruca) or in {CONF} under [mastodon] as api_key")
    return key, model, endpoint, system


def ask(key, model, endpoint, system, question):
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": question},
        ],
    }
    data = json.dumps(payload).encode()
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/sunnyscoop300-a11y/hpo",
        "X-Title": "hpo-mastodon",
    }
    req = urllib.request.Request(endpoint, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            body = r.read()
    except urllib.error.HTTPError as e:
        error_body = e.read()[:400].decode(errors='replace')
        # Fallback: if the chosen model is rate-limited, retry with the default model
        if e.code == 429 and model in LING_FALLBACK:
            nxt = LING_FALLBACK[model]
            print(f"  ({model} er rate-limited, proever {nxt})", file=sys.stderr)
            return ask(key, nxt, endpoint, system, question)
        if e.code == 429 and model != DEFAULT_MODEL:
            print(f"  ({model} er rate-limited, falder tilbage til {DEFAULT_MODEL})", file=sys.stderr)
            return ask(key, DEFAULT_MODEL, endpoint, system, question)
        die(f"request failed ({e.code}): {error_body}")
    except Exception as e:
        die(f"request failed: {e}")

    try:
        j = json.loads(body)
        return j["choices"][0]["message"]["content"].strip()
    except Exception:
        die(f"could not parse response: {body[:400].decode(errors='replace')}")


def main():
    # Extract --ling flag before processing question
    args = [a for a in sys.argv[1:] if a not in ("--ling", "--argon")]
    use_ling = "--ling" in sys.argv
    if not args or not args[0].strip():
        die('usage: mastodon-chat.py [--ling|--argon] "your question"')
    question = " ".join(args)
    key, model, endpoint, system = load_conf()
    if use_ling:
        model = LING_MODEL
    elif "--argon" in sys.argv:
        model = ARGON_MODEL
    answer = ask(key, model, endpoint, system, question)
    print(answer)


if __name__ == "__main__":
    main()
