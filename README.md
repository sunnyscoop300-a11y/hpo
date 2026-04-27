# hpo 🐯
**The Hare Download Manager** — built with [Hare](https://harelang.org)

```
  _    _  _____   ___  
 | |  | ||  __ \ / _ \ 
 | |__| || |__) | | | |
 |  __  ||  ___/| | | |
 | |  | || |    | |_| |
 |_|  |_||_|     \___/ 
```

> *"Anything is possible when you have inner peace."* — Tigress

---

## Features

- **HTTP/HTTPS/FTP** downloads with a dragon progress bar
- **Magnet links** via aria2c with Tigress wisdom on completion 🐯
- **Google Drive** downloads via gdown
- **Rooster links** — AES-256-CBC encrypted URLs you can share safely
- Resume interrupted downloads with `-r`
- Rate limiting with `-R`
- Quiet and no-color modes

---

## Dependencies

| Tool | Purpose |
|------|---------|
| `curl` | HTTP/HTTPS/FTP downloads |
| `aria2c` | Magnet/torrent downloads |
| `openssl` | Rooster link encryption |
| `gdown` | Google Drive downloads |

Install on Debian/Ubuntu/Mint:
```bash
sudo apt install curl aria2 openssl
pip install gdown
```

---

## Build

Requires the [Hare toolchain](https://harelang.org).

```bash
git clone https://github.com/sunnyscoop300-a11y/hpo.git
cd hpo
hare build -o hpo src/main.ha
sudo install -m755 hpo /usr/local/bin/hpo
```

---

## Usage

```
hpo <url|magnet|rooster> [options]

OPTIONS:
  -o <path>     Output file or directory
  -r            Resume interrupted download
  -R <speed>    Rate limit (e.g. 500k, 2m, 1g)
  -u <agent>    Custom User-Agent
  -s <mins>     Seed time after torrent (default: 0)
  --lock <url>  Create a Rooster link (encrypted URL)
  --code <key>  Secret code for Rooster links
  -v            Verbose output
  -q            Quiet mode
  --no-color    Disable colors
  -h            Help
```

---

## Examples

**HTTP download:**
```bash
hpo https://example.com/file.zip
```

**Rate limited download:**
```bash
hpo https://example.com/file.zip -R 2m
```

**Resume interrupted download:**
```bash
hpo https://example.com/file.zip -o /tmp/file.zip -r
```

**Magnet link:**
```bash
hpo "magnet:?xt=urn:btih:abc123..."
```

**Google Drive:**
```bash
hpo https://drive.google.com/file/d/FILE_ID/view
```

**Encrypt a URL into a Rooster link:**
```bash
hpo --lock https://example.com/secret.zip --code mysecret
# Outputs: rooster:?xt=AES256:...
```

**Download via Rooster link:**
```bash
hpo "rooster:?xt=AES256:..." --code mysecret
```

**Rooster + Magnet (ultimate combo):**
```bash
hpo --lock "magnet:?xt=urn:btih:abc123..." --code mysecret
hpo "rooster:?xt=AES256:..." --code mysecret
```

---

## Backends

| URL type | Backend |
|----------|---------|
| `http://` / `https://` / `ftp://` | curl |
| `magnet:` | aria2c |
| `https://drive.google.com/` | gdown |
| `rooster:` | openssl → resolved backend |

---

## Version

hpo 1.4.1
