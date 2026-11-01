# DIYA — e-bogslæser i Hare

Hare kører hele læseren som en lille webserver på `127.0.0.1:7070`.
Hare finder bøgerne, deler dem i sider, gemmer bogmærker og tema og
skriver al HTML'en. Browseren viser bare det, Hare sender.

## Byg og kør

```sh
cd diya
hare build -o diya .
mkdir -p ~/Diya && cp bøger/*.txt ~/Diya/
./diya
```

| Flag | Hvad |
|---|---|
| `./diya ~/Bøger` | brug en anden bogmappe (standard `~/Diya`) |
| `-n` | åbn ikke browseren automatisk |
| `-p 7071` | anden port |

Stop med **Luk Diya** i biblioteket eller Ctrl+C.

## Betjening (ingen JavaScript — alt er Hare + ren HTML/CSS)

- **Side for side:** klik på højre del af siden = næste, venstre del = forrige. `Alt+Shift+N` / `Alt+Shift+F` (Firefox) eller `Alt+N` / `Alt+F` (Chrome) via `accesskey`.
- **⇣ Rul:** hele bogen på én side, rul med musen. Usynlige `loading="lazy"`-pixels (`/mark`) fortæller Hare hvor langt du er nået; bogmærket rykker kun frem. Bøger åbnes med `#sN`, så browseren selv hopper til bogmærket.
- **A− / A+:** skriftstørrelse — og zoom på tegneserie-sider (Hare regner skaleringen ud).

## Bøger

- `.txt` (fx Project Gutenberg — licens-hoved og -hale skæres automatisk væk)
- `.md` (`#`-linjer bliver kapiteloverskrifter)
- Linjer der starter med `Kapitel`, `Chapter`, `Prolog`, `Epilog`, `Del` osv. bliver overskrifter og starter ny side
- `_` i filnavnet bliver til mellemrum i titlen
- `.epub` — pakkes ud én gang til `~/.cache/diya/` med `unzip`, derefter læser Hare OPF-spine, titel og XHTML selv (kræver `unzip`)

## Filer

| Fil | Indhold |
|---|---|
| `main.ha` | argumenter, TCP-server, HTTP-routing, I/O-hjælpere |
| `bog.ha` | find bøger, indlæs, afsnit, paginering |
| `conf.ha` | `~/.config/diya/diya.conf` — tema, skriftstørrelse, bogmærker |
| `epub.ha` | EPUB: udpakning, container.xml → OPF → spine, XHTML → afsnit, entiteter |
| `html.ha` | CSS, Diya-logo, bibliotek, læser, citater |

## Ruter

| URL | Hvad |
|---|---|
| `/` | biblioteket |
| `/laes?bog=N&side=S` | læseren (side er 1-baseret, uden side = bogmærket) |
| `/tema?t=dag\|nat\|kantine` | skift tema |
| `/str?d=op\|ned` | skriftstørrelse 14–30 px |
| `/luk` | stop serveren |
