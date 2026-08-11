#!/usr/bin/env bash
otmpl="$1"
url="$2"
frames=('🐼' '🐾' '🐼' '🥋')
destdir="$(dirname "$otmpl")"
yt-dlp --no-warnings -q --no-playlist -x --audio-format mp3 --embed-metadata --force-overwrites -o "$otmpl" "$url" >/dev/null 2>&1 &
pid=$!
i=0
pct=0
while kill -0 "$pid" 2>/dev/null; do
  f=${frames[$((i % 4))]}
  i=$((i+1))
  if [ "$pct" -lt 95 ]; then
    pct=$((pct + 3))
    if [ "$pct" -gt 95 ]; then pct=95; fi
  fi
  filled=$((pct / 5))
  bar=""
  for ((b=0; b<20; b++)); do
    if [ "$b" -lt "$filled" ]; then bar="${bar}="; else bar="${bar}·"; fi
  done
  printf "\r  %s Po henter... [%s] %3d%%   " "$f" "$bar" "$pct" > /dev/tty
  sleep 0.25
done
wait "$pid"
rc=$?
# Fjern "NA - " prefix fra evt. nye filer
for file in "$destdir"/"NA - "*.mp3; do
  [ -f "$file" ] || continue
  base="$(basename "$file")"
  newbase="${base#NA - }"
  mv -f "$file" "$destdir/$newbase"
done
if [ "$rc" -eq 0 ]; then
  printf "\r  🐼 Po henter... [====================] 100%%   \n" > /dev/tty
  printf "  🐼 Po leverede nummeret! Skadoosh!\n" > /dev/tty
else
  printf "\r  🐼 Po tabte nummeret (fejl)                        \n" > /dev/tty
fi
