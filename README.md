# hpo 🐯

**The Hare Download, Game & Media Manager** — a Kung Fu Panda + Rooster Fighter + The Wild Robot themed CLI multitool written in [Hare](https://harelang.org/).

---

## Features

### 📥 Downloads
- **HTTP/HTTPS/FTP** via curl with a dragon-themed progress bar
- **Magnet links** via aria2c
- **Google Drive** via gdown (multi-library aware)
- **Mega** via megadl
- **Rooster links** — share any URL encrypted with AES-256-CBC; only the right code unlocks it
- **Suno music** with auto MP3 conversion
- Rate limiting, resume, custom User-Agent, cookies, tokens

### 🐆 Tai Lung — Parallel Download
- `hpo tailung <url1> <url2> <url3> ...`
- Breaks out and fires **all downloads at once** — true parallel execution
- Reports how many succeeded / failed when the dust settles

### 🐓 Rooster Links (encrypted sharing)
```bash
hpo --lock https://example.com/secret.zip --code "skadoosh123"
# -> rooster:?xt=AES256:U2FsdGVkX1...
hpo "rooster:?xt=AES256:U2FsdGVkX1..." --code "skadoosh123"
```
Works with HTTP, Google Drive, and magnet links alike — the encrypted token is safe to share publicly.

---

## 🎮 Gaming

### 🎮 Game Launchers
- **Epic Games** via legendary + Zhen engine (Linux) or PowerShell bridge (WSL)
- **Steam / Foxfire** via URI handler + Zhen GE-Proton (Linux) or PowerShell bridge (WSL)
- **`hpo --steam list`** — shows installed games with names + AppIDs (works on WSL too)
- Launch shows the full game name, looked up from Steam's manifests
- Per-game aliases in `~/.config/hpo/{steam,epic}_aliases.txt`

### 🐉 Zhen Engine
- Self-contained gaming runtime built on **umu-launcher + GE-Proton11-1**
- Auto-symlinks GE-Proton into Steam's `compatibilitytools.d`
- Install: `hpo --zhen-setup --proton`
- Update: `hpo --zhen-update`
- On WSL: bridges Steam/Epic to Windows via PowerShell `Start-Process`

### ⚽ Monkey — Rocket League
- `hpo monkey` — launches Rocket League via Epic (legendary) + umu + GE-Proton11-1
- Handles Easy Anti-Cheat (EAC) through umu's EGS protonfixes
- `hpo monkey setup` — install Rocket League

### 🗡️ Bnet — Battle.net / World of Warcraft
- `hpo bnet` — launches Battle.net (and WoW) via Zhen + umu
- DRM-safe launch flags for a stable Blizzard login

### 🐍 Viper — PlayStation Remote Play
- `hpo viper` — PS5/PS4 Remote Play via chiaki-ng (Flatpak)
- Stream your own console over the network

### 🦆 Mr. Ping — Roblox
- `hpo ping` — launches Roblox via Sober (Flatpak)

### 🐊 Croc — Space Cadet Pinball
- `hpo croc` — Master Croc racks the ball! Classic 3D Space Cadet Pinball
- `hpo croc setup` — install via Flatpak (open-source SpaceCadetPinball engine)

### 🐤 Piyoko Arcade — Retro Gaming
- `hpo xp <system> <game>` — multi-system retro arcade
- Systems: NES, SNES, Genesis (via MAME), Game Boy (mGBA), PSX (DuckStation)
- Earn Piyokocoin as you play
- **Legal note:** works with your *own* game dumps, homebrew, and free MAME ROMs only

---

## 🎵 Media

### 🐦 Crane — Music Player
*Elegant and soaring* — Crane streams music from anywhere.
- `hpo crane search <words>` — SoundCloud search
- `hpo crane radio <words>` — SoundCloud radio (10 tracks in a row)
- `hpo crane yt <words>` — YouTube search
- `hpo crane ytradio <words>` — YouTube radio (10 tracks)
- `hpo crane local <path>` — play local music (Suno tracks, downloads)
- `hpo crane mix <path>` — **DJ mode**: shuffle + loop your collection
- `hpo crane web <words>` — open SoundCloud search in your browser
- `hpo crane <url>` — play a direct SoundCloud/YouTube URL
- Respects DRM — skips protected tracks (plays only freely available music)

### 🐃 Kai — Anime Player with Anime4K
*"Take his chi!"* — Kai makes your anime jade-sharp.
- `hpo kai <file>` — play a local anime/video with **Anime4K upscaling**
- `hpo kai <folder>` — play a whole folder
- `hpo kai <youtube-url>` — YouTube in **1080p + Anime4K**
- `hpo kai <search words>` — search YouTube and play
- Perfect for your own anime Blu-rays (rip with MakeMKV → jade-sharp playback)
- Anime4K v4.0 shaders (MIT) in `~/.config/mpv/shaders/`, tuned for 1080p

### 🦗 Mantis — Manga Cart Hub
- `hpo mantis` — a themed TUI hub for tracking manga carts
- Keep your reading list and shopping carts in one place

### 🥋 Master Shifu Cinema Oracle
- **Live schedules** for 90+ Danish cinemas via `bio.ebillet.dk`
- Day filter: `idag`, `imorgen`, weekday names, `weekend`, `uge`
- **Fuzzy match** — suggests the nearest cinema if you mistype
- Custom ASCII portrait via `~/.config/hpo/art/shifu.txt`

---

## 🛠️ Tools & Extras

### 🦎 Chameleon — Save Manager
*"Your power... is now MINE!"* — The Chameleon steals (backs up) and restores your game saves.
- `hpo chameleon backup <alias>` — back up a Steam Cloud save
- `hpo chameleon backup --epic <alias>` — back up an Epic Cloud save
- `hpo chameleon list` — show all saves with names + dates
- `hpo chameleon restore <alias>` — restore the latest backup
- **Auto-prune**: keeps only the newest backup per game
- Saves stored in `~/hpo-saves/`

### 🐯 Tigress — Quote of the Day
- `hpo tigress` — a daily dose of motivation from Master Tigress
- Same quote all day, changes at midnight

### 🪙 Piyoko — Piyokocoin Wallet
- `hpo piyoko` — show your Piyokocoin balance with 8-bit coin art
- Earn **1 Piyokocoin per completed download**, automatically
- `hpo piyoko spin`, `hpo piyoko cook`, `hpo piyoko cookbook`, `hpo piyoko recipe <n>`
- Balance stored in `~/.config/hpo/piyokocoin`

### 🐢 Oogway Meditation
- Guided meditation with **Master Oogway** quotes and a breathing bar
- `hpo oogway 60` (1 min), `hpo oogway 300` (5 min)
- Real monastery bell via mpv (`~/.local/share/hpo/bell.mp3`)

### 🤖 Roz Weather Robot
- Auto-locates via `ip-api.com`, weather from **Open-Meteo** (no API keys)
- City override: `hpo roz vejr københavn`, `hpo roz vejr sydney`
- Poetic, Wild-Robot-themed descriptions; full Unicode (ø, æ, å)

### 🩺 Doctor & Setup
- `hpo doctor` — system health check (verifies tools & backends)
- `hpo --setup` — install everything (apt + pip + Zhen + emulators)
- `install.sh` — beginner-friendly bootstrap (builds Hare + hpo from scratch)

---

## Installation

### Requirements
- [Hare](https://harelang.org/) compiler (`harec`, `qbe`) — built/tested on Hare 0.26.0
- `curl`, `aria2c`, `openssl`, `xdg-open` for download backends
- `gdown` (`pip install gdown`) for Google Drive
- `mpv` for the Oogway bell, Crane music, and Kai video
- `python3` for the Shifu cinema helper
- `legendary` (`pipx install legendary-gl`) for Epic Games on Linux
- `yt-dlp` for Crane/Kai YouTube support
- Optional: Flatpak Steam or native `steam`

### Build
```bash
git clone https://github.com/sunnyscoop300-a11y/hpo.git
cd hpo
hare build -o hpo src/
sudo install -m755 hpo /usr/local/bin/hpo
sudo install -m755 helpers/shifu-events.py /usr/local/share/hpo/
```

Or use the beginner-friendly bootstrap (builds the whole Hare toolchain first):
```bash
./install.sh
```

### Zhen Engine (for Epic/Steam gaming)
```bash
hpo --zhen-setup --proton
```

### Anime4K shaders (for Kai)
```bash
mkdir -p ~/.config/mpv/shaders
cd ~/.config/mpv/shaders
curl -LO https://github.com/bloc97/Anime4K/releases/download/v4.0.1/Anime4K_v4.0.zip
unzip -o Anime4K_v4.0.zip
```

### YouTube setup (for Crane & Kai)
YouTube's 2026 anti-bot system needs a JavaScript runtime. Install Deno and configure yt-dlp:
```bash
curl -fsSL https://deno.land/install.sh | sh
mkdir -p ~/.config/yt-dlp
cat > ~/.config/yt-dlp/config << 'EOF'
--js-runtimes deno:$HOME/.deno/bin/deno
--remote-components ejs:github
--cookies-from-browser brave
--extractor-args youtube:player_client=web_safari
EOF
```

### Bell sound for Oogway
```bash
mkdir -p ~/.local/share/hpo
curl -L -o ~/.local/share/hpo/bell.mp3 \
  "https://archive.org/download/LovelyMeditationBell/STE-015.mp3"
```

---

## Platforms

| Platform | Steam Backend | Epic Backend |
|----------|---------------|--------------|
| 🦊 FluxLinux | Flatpak + Zhen GE-Proton | legendary + Zhen |
| 🐯 Native Linux | Native Steam + Zhen | legendary + Zhen |
| 🪟 WSL Ubuntu | PowerShell → Windows Steam | PowerShell → Windows Epic |

Same `hpo` binary, same commands — adapts to the environment automatically. On WSL, Chameleon reads Steam/Epic saves directly via `/mnt/c`.

---

## Caching

| File | TTL | Purpose |
|------|-----|---------|
| `~/.cache/hpo/location.json` | 7 days | IP geolocation |
| `~/.cache/hpo/cinemas_*.json` | 7 days | Cinema list per location |
| `~/.cache/hpo/events.json` | 6 hours | All Danish cinema showings |

This makes `hpo shifu` go from ~1.7s to ~4ms on the second call (**~400x faster**).

---

## Theming

hpo draws on **Kung Fu Panda**, **Rooster Fighter**, and **The Wild Robot**:

- 🐯 **Po / Tigress** — Steam alias & quote of the day
- 🐉 **Zhen** — the gaming engine (KFP4)
- 🦎 **The Chameleon** — save manager villain (KFP4)
- 🐆 **Tai Lung** — parallel download (KFP1)
- 🐵 **Monkey** — Rocket League (Furious Five)
- 🐍 **Viper** — PlayStation Remote Play (Furious Five)
- 🦗 **Mantis** — manga cart hub (Furious Five)
- 🐦 **Crane** — music player (Furious Five)
- 🐃 **Kai** — anime player with Anime4K (KFP3, the jade master)
- 🐊 **Master Croc** — Space Cadet Pinball (Kung Fu Council)
- 🐢 **Oogway** — meditation
- 🥋 **Shifu** — cinema oracle
- 🗡️ **Bnet** — Battle.net / WoW launcher
- 🦆 **Mr. Ping** — Roblox launcher
- 🐤 **Piyoko** — Piyokocoin wallet & retro arcade (Rooster Fighter)
- 🐓 **Rooster / Keiji** — encrypted Rooster links (Rooster Fighter)
- 🤖 **Roz / Brightbill** — weather robot (The Wild Robot)

---

## Legal

hpo only helps with legal content: your own files, purchased games (Steam/Epic/GOG),
your own disc/cartridge dumps, your own Blu-rays (personal backups via MakeMKV),
your own Suno generations, free MAME ROMs, homebrew, and freely-available streaming.
It respects DRM and does not circumvent copy protection.

---

## Personal Project

hpo is a hobby project by Bossun, built across:
- 🦊 FluxLinux (i7-6800K + GTX 1070)
- 🪟 WSL Ubuntu on Windows 11 (i7-13700K + RTX 4070)
- 🐯 EndeavourOS

Written in **Hare** because it's fun. Themed around **Kung Fu Panda** because Po is the Dragon Warrior. 🍍

**Skadoosh!**
