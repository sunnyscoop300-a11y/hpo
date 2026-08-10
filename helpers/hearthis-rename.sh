#!/usr/bin/env bash
# Renames a downloaded MP3 to "Artist - Title.mp3" using its ID3 tags.
# Usage: hearthis-rename.sh /path/to/file.mp3
set -euo pipefail
f="$1"
[ -f "$f" ] || exit 0
dir="$(dirname "$f")"
artist="$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | head -1)"
title="$(ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | head -1)"
# Sanitize (remove slashes)
artist="${artist//\//-}"
title="${title//\//-}"
if [ -n "$artist" ] && [ -n "$title" ]; then
    new="$dir/$artist - $title.mp3"
    if [ "$f" != "$new" ]; then
        mv -f "$f" "$new"
        echo "  Renamed: $artist - $title.mp3"
    fi
fi
