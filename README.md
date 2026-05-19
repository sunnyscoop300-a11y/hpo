# hpo 🐯

**The Hare Download & Game Manager** — a Kung Fu Panda + The Wild Robot themed CLI multitool written in [Hare](https://harelang.org/).
---

## Features

### 📥 Downloads
- **HTTP/HTTPS/FTP** via curl with dragon-themed progress bar
- **Magnet links** via aria2c
- **Google Drive** via gdown
- **Rooster links** with AES-256-CBC encryption
- **Suno music** with auto MP3 conversion
- Rate limiting, resume, custom User-Agent, cookies, tokens

### 🎮 Game Launchers
- **Epic Games** via legendary + Zhen engine
- **Steam** via URI handler + Zhen GE-Proton
- **WSL bridge** — Both Steam & Epic URIs forwarded to Windows host via `cmd.exe /c start`
- Per-game aliases in `~/.config/hpo/{steam,epic}_aliases.txt`

### 🐉 Zhen Engine
- Self-contained gaming runtime built on **umu-launcher + GE-Proton10-34**
- Replaces Heroic/Lutris with a clean Hare-based wrapper
- Auto-symlinks GE-Proton into Steam's `compatibilitytools.d`
- Install: `hpo --zhen-setup --proton`

### 🐢 Oogway Meditation
- 10-min guided meditation with **Master Oogway** quotes
- Custom durations: `hpo oogway 60` (1 min), `hpo oogway 300` (5 min)
- Real monastery bell sound via mpv
- Visual breathing bar
- Bell file: `~/.local/share/hpo/bell.mp3`

### 🤖 Roz Weather Robot
- Auto-locates you via `ip-api.com` (no API key needed)
- Pulls weather from **Open-Meteo API**
- City override: `hpo roz vejr københavn`, `hpo roz vejr sydney`
- Poetic Brightbill-themed weather descriptions
- Works globally with Unicode support (ø, æ, å)

### 🥋 Master Shifu Cinema Oracle
- **Live schedules** for 90+ Danish cinemas via `bio.ebillet.dk`
- Day filter: `idag`, `imorgen`, weekday names (`torsdag`), `weekend`, `uge`
- Custom ASCII portrait via `~/.config/hpo/art/shifu.txt`
- Cinema lookup via `~/.config/hpo/cinemas.json`
- Examples:
---

## Installation

### Requirements
- [Hare](https://harelang.org/) compiler (`harec`, `qbe`)
- `curl`, `aria2c`, `openssl`, `xdg-open` for download backends
- `mpv` for Oogway bell audio
- `python3` for Shifu cinema helper
- `legendary` (`pipx install legendary-gl`) for Epic Games
- Optional: `flatpak` Steam or native `steam`

### Build
```bash
git clone https://github.com/sunnyscoop300-a11y/hpo.git
cd hpo
hare build -o hpo src/main.ha
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
| 🪟 WSL Ubuntu | cmd.exe → Windows Steam | cmd.exe → Windows Epic |

Same `hpo` binary, same commands — adapts to environment automatically.

---

## Caching

For speed and to be a good API neighbor, hpo caches:

| File | TTL | Purpose |
|------|-----|---------|
| `~/.cache/hpo/location.json` | 7 days | IP geolocation |
| `~/.cache/hpo/cinemas_*.json` | 7 days | Overpass cinema list per location |
| `~/.cache/hpo/events.json` | 6 hours | All Danish cinema showings |

This makes `hpo shifu` go from ~1.7s to ~4ms on second call (**~400x faster**).

---

## Theming

hpo is themed around **Kung Fu Panda** and **The Wild Robot**:

- 🐯 **Po** — main character; default Steam alias  
- 🦊 **Zhen** — the engine (from KFP4)
- 🐢 **Oogway** — meditation feature
- 🥋 **Shifu** — cinema mentor
- 🤖 **Roz** — Rozzum Unit 7134, weather robot from The Wild Robot
- 🐦 **Brightbill** — referenced in weather poetry

---

## Personal Project

hpo is a hobby project by Bossun, built across:
- 🦊 FluxLinux 1.4 (i7-6800K + GTX 1070)
- 🐯 Void Linux laptop (i5 gen 8 + Intel iGPU)
- 🪟 WSL Ubuntu on Windows 11 (i7-13700K + RTX 4070)

Written in **Hare** because it's fun. Themed around **Kung Fu Panda** because Po is the Dragon Warrior. 🍍

**Skadoosh!**
