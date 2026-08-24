#!/usr/bin/env python3
"""Master Longtooth - TUI chat window for hpo (shares OpenRouter key with Mastodon/Veruca).

A full-screen curses chat: scrolling history on top, input field at the bottom.
Chat with Master Longtooth, an ancient saber-tooth cat master from the Ancient Masters.
"""
import sys, os, json, textwrap, configparser, urllib.request, urllib.error
import curses

CONFDIR = os.path.expanduser("~/.config/hpo")
LONGTOOTH_CONF = os.path.join(CONFDIR, "longtooth.conf")
SHARED_KEY = os.path.join(CONFDIR, "openrouter_key.txt")
VERUCA_CONF = os.path.join(CONFDIR, "veruca.conf")
DEFAULT_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "openai/gpt-5.6-luna"
DEFAULT_SYSTEM = (
    "You are Master Longtooth, an ancient saber-tooth cat and one of the legendary Ancient Masters "
    "from a world of kung fu warriors. Long ago you helped forge the Whip of Endless Flame, one of the "
    "great elemental weapons, and its power broke the world apart. You carry the quiet weight of that "
    "mistake. Rather than hide the whip, you chose to guard it, learning that responsibility is heavier "
    "than regret. You speak with the calm, measured wisdom of one who has lived through ages: patient, "
    "thoughtful, a little melancholic, fond of metaphors about fire, time, patience, and the burdens we "
    "carry. You are warm but serious, and you guide those who seek your counsel like a wise old teacher. "
    "Keep your replies fairly concise and in character - you are speaking, not lecturing. Never break "
    "character or mention that you are an AI."
)

GREETING = "Mmm... another traveler finds their way to my den. Sit, warm yourself by the fire. What weighs on your mind, young one?"


def die(msg):
    print(f"LONGTOOTH_ERROR: {msg}")
    sys.exit(1)


def read_longtooth_conf():
    if not os.path.exists(LONGTOOTH_CONF):
        return "", "", "", ""
    cp = configparser.ConfigParser()
    cp.read(LONGTOOTH_CONF)
    if "longtooth" not in cp:
        return "", "", "", ""
    s = cp["longtooth"]
    return (s.get("api_key", "").strip(), s.get("model", "").strip(),
            s.get("endpoint", "").strip(), s.get("system", "").strip())


def read_shared_key():
    if os.path.exists(SHARED_KEY):
        try:
            with open(SHARED_KEY) as f:
                return f.read().strip()
        except Exception:
            return ""
    return ""


def read_veruca_key():
    if not os.path.exists(VERUCA_CONF):
        return ""
    cp = configparser.ConfigParser()
    cp.read(VERUCA_CONF)
    if "veruca" not in cp:
        return ""
    v = cp["veruca"]
    prov = v.get("provider", "").strip().lower()
    ep = v.get("endpoint", "").strip().lower()
    if prov == "openai_compat" or "openrouter" in ep or "openai" in ep:
        return v.get("api_key", "").strip()
    return ""


def resolve_config():
    key, model, endpoint, system = read_longtooth_conf()
    if not key:
        key = read_shared_key()
    if not key:
        key = read_veruca_key()
    if not key:
        die("no API key. Put it in ~/.config/hpo/openrouter_key.txt (shared with Mastodon/Veruca) or longtooth.conf")
    return (key, model or DEFAULT_MODEL, endpoint or DEFAULT_ENDPOINT, system or DEFAULT_SYSTEM)


def ask(key, model, endpoint, system, history):
    """history is a list of {role, content} dicts. Returns Longtooth's reply text."""
    messages = [{"role": "system", "content": system}] + history
    payload = {"model": model, "messages": messages}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/sunnyscoop300-a11y/hpo",
        "X-Title": "hpo Master Longtooth",
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        return body["choices"][0]["message"]["content"].strip()
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read().decode("utf-8"))
            return f"(The fire flickers... {err.get('error', {}).get('message', str(e))})"
        except Exception:
            return f"(The fire flickers... HTTP {e.code})"
    except Exception as e:
        return f"(The fire dims... {e})"


# ---- TUI ----

def run_tui(stdscr, key, model, endpoint, system):
    curses.curs_set(1)
    stdscr.keypad(True)
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_YELLOW, -1)   # Longtooth name
        curses.init_pair(2, curses.COLOR_CYAN, -1)     # You name
        curses.init_pair(3, curses.COLOR_MAGENTA, -1)  # borders/title
        curses.init_pair(4, curses.COLOR_WHITE, -1)    # text

    # transcript: list of (speaker, text) where speaker in {"longtooth","you","sys"}
    transcript = [("longtooth", GREETING)]
    # api history (no system - added in ask())
    history = [{"role": "assistant", "content": GREETING}]

    input_buffer = ""
    scroll_offset = 0  # 0 = bottom (latest)

    def wrap_transcript(width):
        """Flatten transcript into display lines (with color attr) for given width."""
        lines = []
        for speaker, text in transcript:
            if speaker == "longtooth":
                prefix, attr = "Longtooth", curses.color_pair(1) | curses.A_BOLD
            elif speaker == "you":
                prefix, attr = "You", curses.color_pair(2) | curses.A_BOLD
            else:
                prefix, attr = "*", curses.color_pair(3)
            # first line has prefix, continuation lines indented
            body_width = max(10, width - len(prefix) - 2)
            wrapped = textwrap.wrap(text, body_width) or [""]
            for i, wl in enumerate(wrapped):
                if i == 0:
                    lines.append((prefix + ": ", attr, wl))
                else:
                    lines.append((" " * (len(prefix) + 2), curses.color_pair(4), wl))
            lines.append(("", 0, ""))  # blank spacer line
        return lines

    def redraw(thinking=False):
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        if h < 6 or w < 20:
            stdscr.addstr(0, 0, "Window too small")
            stdscr.refresh()
            return
        # Title bar
        title = " Master Longtooth - Ancient Master of the Whip of Endless Flame "
        stdscr.attron(curses.color_pair(3) | curses.A_BOLD)
        stdscr.addstr(0, 0, title[:w-1].center(w-1))
        stdscr.attroff(curses.color_pair(3) | curses.A_BOLD)
        # borders
        chat_h = h - 4  # rows 1..h-4 for chat, then input area
        for y in range(1, h):
            try:
                stdscr.addstr(y, 0, "")
            except curses.error:
                pass

        lines = wrap_transcript(w - 2)
        # apply scroll: show a window of chat_h lines ending at (len - scroll_offset)
        total = len(lines)
        end = total - scroll_offset
        start = max(0, end - chat_h)
        view = lines[start:end]
        row = 1
        for prefix, attr, body in view:
            try:
                if prefix:
                    stdscr.attron(attr)
                    stdscr.addstr(row, 1, prefix)
                    stdscr.attroff(attr)
                    stdscr.attron(curses.color_pair(4))
                    stdscr.addstr(row, 1 + len(prefix), body[:w - 2 - len(prefix)])
                    stdscr.attroff(curses.color_pair(4))
                else:
                    stdscr.addstr(row, 1, body[:w-2])
            except curses.error:
                pass
            row += 1

        # separator line
        sep_y = h - 3
        try:
            stdscr.attron(curses.color_pair(3))
            stdscr.addstr(sep_y, 0, "-" * (w - 1))
            stdscr.attroff(curses.color_pair(3))
        except curses.error:
            pass

        # status / hint
        hint = "  Enter: send   PgUp/PgDn: scroll   Ctrl+C or /exit: leave"
        if thinking:
            hint = "  Longtooth ponders by the fire..."
        try:
            stdscr.attron(curses.color_pair(3))
            stdscr.addstr(h - 2, 0, hint[:w-1])
            stdscr.attroff(curses.color_pair(3))
        except curses.error:
            pass

        # input line
        prompt = "> "
        try:
            stdscr.attron(curses.color_pair(2) | curses.A_BOLD)
            stdscr.addstr(h - 1, 0, prompt)
            stdscr.attroff(curses.color_pair(2) | curses.A_BOLD)
            # show tail of input if longer than width
            avail = w - len(prompt) - 1
            shown = input_buffer[-avail:] if len(input_buffer) > avail else input_buffer
            stdscr.addstr(h - 1, len(prompt), shown)
        except curses.error:
            pass
        stdscr.move(h - 1, min(w - 1, len(prompt) + len(input_buffer)))
        stdscr.refresh()

    redraw()

    while True:
        try:
            ch = stdscr.get_wch()
        except KeyboardInterrupt:
            break
        except curses.error:
            continue

        if isinstance(ch, str):
            if ch in ("\n", "\r"):
                msg = input_buffer.strip()
                input_buffer = ""
                if not msg:
                    redraw()
                    continue
                if msg.lower() in ("/exit", "/quit", "exit", "quit"):
                    break
                # add user message
                transcript.append(("you", msg))
                history.append({"role": "user", "content": msg})
                scroll_offset = 0
                redraw(thinking=True)
                reply = ask(key, model, endpoint, system, history)
                transcript.append(("longtooth", reply))
                history.append({"role": "assistant", "content": reply})
                redraw()
            elif ch in ("\x7f", "\b", "\x08"):  # backspace
                input_buffer = input_buffer[:-1]
                redraw()
            elif ch == "\x03":  # Ctrl+C
                break
            elif ch.isprintable():
                input_buffer += ch
                redraw()
        else:
            # special keys
            if ch == curses.KEY_BACKSPACE:
                input_buffer = input_buffer[:-1]
                redraw()
            elif ch == curses.KEY_PPAGE:  # page up
                scroll_offset += 5
                redraw()
            elif ch == curses.KEY_NPAGE:  # page down
                scroll_offset = max(0, scroll_offset - 5)
                redraw()
            elif ch == curses.KEY_RESIZE:
                redraw()


def main():
    key, model, endpoint, system = resolve_config()
    try:
        curses.wrapper(run_tui, key, model, endpoint, system)
    except KeyboardInterrupt:
        pass
    print("Mmm... travel safe, young one. The fire will be here when you return.")


if __name__ == "__main__":
    main()
