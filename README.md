# hpo 🐯🐉

**The Hare Download & Game Manager** — built with [Hare](https://harelang.org)
> *"There are no accidents."* — Master Oogway

A self-contained CLI tool that downloads files, launches Epic and Steam games via a custom self-built engine, and even guides you through a 10-minute meditation with Master Oogway and a real Tibetan bell.

---

## ✨ Features

### 🎮 Game Launchers
- **Epic Games** via [legendary](https://github.com/derrod/legendary) + Zhen engine
- **Steam** via URI handler with auto Zhen-Proton symlinking
- **Zhen engine** — self-contained gaming runtime (umu-launcher + GE-Proton)
- No dependency on Heroic, Lutris, or other launchers
- Short alias syntax: `hpo --steam kao` launches Kao the Kangaroo

### 📥 Downloads
- **HTTP/HTTPS/FTP** with dragon progress bar
- **Google Drive** via gdown
- **Magnet links** via aria2c
- **Rooster links** — AES-256-CBC encrypted URLs
- **Suno music** with HTML entity decoder + auto MP3 conversion
- **Bearer token** and **cookie** auth support
- Resume, rate limiting, custom User-Agent

### 🐢 Inner Peace
- `hpo oogway` — 10-minute guided meditation
- 14 timed coaching messages from Master Oogway
- Visual breathing guide (4s in, 4s hold, 4s out)
- Real meditation bell from Big Sur, CA (CC0)

---

## 📦 Installation

### Dependencies
```bash
# Debian/Ubuntu/FluxLinux
sudo apt install curl aria2 openssl ffmpeg python3-pip mpv
pipx install gdown legendary-gl

# Void Linux
sudo xbps-install -S curl aria2 openssl ffmpeg legendary mpv
```

### Build hpo
```bash
git clone https://github.com/sunnyscoop300-a11y/hpo.git
cd hpo
hare build -o hpo src/main.ha
sudo install -m755 hpo /usr/local/bin/hpo
```

### Install Zhen engine (for game launching)
```bash
hpo --zhen-setup --proton   # ~700 MB download
```

### Install meditation bell (optional, for hpo oogway)
```bash
mkdir -p ~/.local/share/hpo
curl -L -o ~/.local/share/hpo/bell.mp3 \
  "https://archive.org/download/LovelyMeditationBell/STE-015.mp3"
```

---

## 🚀 Usage

### Downloads
```bash
hpo https://example.com/file.zip
hpo https://example.com/big.iso -R 2m -r
hpo "magnet:?xt=urn:btih:abc123..."
hpo --lock https://secret.com/file.zip --code mykey
hpo "rooster:?xt=AES256:..." --code mykey
```

### Epic Games
```bash
hpo --epic list
hpo --epic install Salt
hpo --epic launch celeste
```

### Steam
```bash
hpo --steam list
hpo --steam install 1370140
hpo --steam launch kao
hpo --steam kao
```

Steam aliases live in `~/.config/hpo/steam_aliases.txt`:
### Meditation
```bash
hpo oogway
```

---

## 🐉 The Zhen Engine

Zhen is hpo's self-contained gaming runtime, named after the fox who becomes the next Dragon Warrior in Kung Fu Panda 4. It bundles:

- **umu-launcher** 1.4.0 (Wine/Proton wrapper)
- **GE-Proton10-34** (Glorious Eggroll's Proton fork)

Installed to `~/.local/share/hpo/zhen/`. No system Wine needed. Steam games auto-symlink GE-Proton to Steam's `compatibilitytools.d`.

---

## 🎮 Confirmed Working Games

**FluxLinux (GTX 1070):**
- ABZU, GRIME (Epic)
- DreamWorks All-Star Kart Racing 🐼 (Steam)
- Kao the Kangaroo 🦘 (Steam)

**Void Linux (Intel iGPU, gen 8 i5):**
- Celeste 🏔️ (Epic, via XNA/FNA)

---

## 🛠️ Architecture

Written in [Hare](https://harelang.org) — a small systems programming language with manual memory management and no garbage collection. The entire launcher, download manager, and meditation session is one statically-linked binary.

**Backends invoked via `os::exec`:**
- HTTP/HTTPS/FTP → `curl`
- Google Drive → `gdown`
- Magnet → `aria2c`
- Rooster → `openssl`
- Suno → `curl` + `ffmpeg`
- Epic → `legendary` + Zhen umu-run
- Steam → URI handler (`xdg-open steam://...`)
- Meditation bell → `mpv`

---

## 🐢 Philosophy

> *"Yesterday is history. Tomorrow is a mystery. But today is a gift. That is why it is called the present."*
> — Master Oogway

hpo is a hobby project. It is not perfect. But it is mine, and it is what I wanted to build. Skadoosh!

---

## 📄 License

MIT

---

*Built with Hare, GE-Proton, Big Sur bells, and Kung Fu Panda energy.* 🥋🍍
