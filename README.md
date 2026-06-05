# hpo 🐯

**The Hare Download & Game Manager** — a Kung Fu Panda + Rooster Fighter + The Wild Robot themed CLI multitool written in [Hare](https://harelang.org/).

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

### 🎮 Game Launchers
- **Epic Games** via legendary + Zhen engine (Linux) or PowerShell bridge (WSL)
- **Steam / Foxfire** via URI handler + Zhen GE-Proton (Linux) or PowerShell bridge (WSL)
- **`hpo --steam list`** — shows installed games with names + AppIDs (works on WSL too)
- Launch shows the full game name, looked up from Steam's manifests
- Per-game aliases in `~/.config/hpo/{steam,epic}_aliases.txt`

### 🦎 Chameleon — Save Manager
*"Your power... is now MINE!"* — The Chameleon steals (backs up) and restores your game saves.
- `hpo chameleon backup <alias>` — back up a Steam Cloud save
- `hpo chameleon backup --epic <alias>` — back up an Epic Cloud save
- `hpo chameleon list` — show all saves with names + dates
- `hpo chameleon restore <alias>` — restore the latest backup
- **Auto-prune**: keeps only the newest backup per game
- Saves stored in `~/hpo-saves/`

### 🐉 Zhen Engine
- Self-contained gaming runtime built on **umu-launcher + GE-Proton10-34**
- Auto-symlinks GE-Proton into Steam's `compatibilitytools.d`
- Install: `hpo --zhen-setup --proton`
- Update: `hpo --zhen-update`
- On WSL: bridges Steam/Epic to Windows via PowerShell `Start-Process`

### 🐯 Tigress — Quote of the Day
- `hpo tigress` — a daily dose of motivation from Master Tigress
- Same quote all day, changes at midnight

### 🪙 Piyoko — Piyokocoin Wallet
- `hpo piyoko` — show your Piyokocoin balance with 8-bit coin art
- Earn **1 Piyokocoin per completed download**, automatically
- Balance stored in `~/.config/hpo/piyokocoin`

### 🐢 Oogway Meditation
- Guided meditation with **Master Oogway** quotes and a breathing bar
- `hpo oogway 60` (1 min), `hpo oogway 300` (5 min)
- Real monastery bell via mpv (`~/.local/share/hpo/bell.mp3`)

### 🤖 Roz Weather Robot
- Auto-locates via `ip-api.com`, weather from **Open-Meteo** (no API keys)
- City override: `hpo roz vejr københavn`, `hpo roz vejr sydney`
- Poetic, Wild-Robot-themed descriptions; full Unicode (ø, æ, å)

### 🥋 Master Shifu Cinema Oracle
- **Live schedules** for 90+ Danish cinemas via `bio.ebillet.dk`
- Day filter: `idag`, `imorgen`, weekday names, `weekend`, `uge`
- **Fuzzy match** — suggests the nearest cinema if you mistype
- Custom ASCII portrait via `~/.config/hpo/art/shifu.txt`

---

## Installation

### Requirements
- [Hare](https://harelang.org/) compiler (`harec`, `qbe`) — built/tested on Hare 0.26.0
- `curl`, `aria2c`, `openssl`, `xdg-open` for download backends
- `gdown` (`pip install gdown`) for Google Drive
- `mpv` for the Oogway bell
- `python3` for the Shifu cinema helper
- `legendary` (`pipx install legendary-gl`) for Epic Games on Linux
- Optional: Flatpak Steam or native `steam`

### Build
```bash
git clone https://github.com/sunnyscoop300-a11y/hpo.git
cd hpo
hare build -o hpo src/
sudo install -m755 hpo /usr/local/bin/hpo
sudo install -m755 helpers/shifu-events.py /usr/local/share/hpo/
```

### Zhen Engine (for Epic/Steam gaming)
```bash
hpo --zhen-setup --proton
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
- 🦊 **Zhen** — the gaming engine (KFP4)
- 🦎 **The Chameleon** — save manager villain (KFP4)
- 🐆 **Tai Lung** — parallel download (KFP1)
- 🐢 **Oogway** — meditation
- 🥋 **Shifu** — cinema oracle
- 🐓 **Rooster / Keiji** — encrypted Rooster links (Rooster Fighter)
- 🪙 **Piyoko** — Piyokocoin wallet (Rooster Fighter)
- 🤖 **Roz / Brightbill** — weather robot (The Wild Robot)

---

## Personal Project

hpo is a hobby project by Bossun, built across:
- 🦊 FluxLinux (i7-6800K + GTX 1070)
- 🪟 WSL Ubuntu on Windows 11 (i7-13700K + RTX 4070)
- 🐯 EndeavourOS

Written in **Hare** because it's fun. Themed around **Kung Fu Panda** because Po is the Dragon Warrior. 🍍

**Skadoosh!**
