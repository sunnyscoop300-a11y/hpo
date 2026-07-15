#!/usr/bin/env bash
# Akna - hpo config memory wizard
# Saves/restores your entire hpo setup (config + games + art) to a USB tar.gz
# Usage:
#   akna-wizard.sh save <dest-dir>
#   akna-wizard.sh restore <src-dir>
#   akna-wizard.sh list <src-dir>

set -u
ACTION="${1:-}"
TARGET="${2:-}"
BACKUP_NAME="akna-hpo-backup.tar.gz"
CFG="$HOME/.config/hpo"
STAGE="/tmp/akna-stage"
BACKUP_ALL="akna-hpo-full.tar.gz"
# Manga carts (source projects) - relative to $HOME
CARTS=(
  "Documents/sakamoto"
  "Documents/Ichi"
  "Music/Atlas77/williamdam_cart"
  "Music/Atlas77/blacktorch_cart"
)

die() { echo "AKNA_ERROR: $*"; exit 1; }

case "$ACTION" in
  save)
    [ -n "$TARGET" ] || die "no destination given"
    [ -d "$TARGET" ] || die "destination not found: $TARGET"
    [ -d "$CFG" ] || die "no hpo config at $CFG"

    rm -rf "$STAGE"; mkdir -p "$STAGE/config"
    # 1. Copy the whole hpo config (aliases, keys, requires_native, piyokocoin, art)
    cp -r "$CFG/." "$STAGE/config/" 2>/dev/null

    # 2. Generate a game list (Flatpak apps + Steam appids installed via zhen)
    {
      echo "# Akna hpo game snapshot - $(date -Iseconds)"
      echo "## Flatpak apps"
      flatpak list --app --columns=application 2>/dev/null | sort -u
      echo "## Steam appids (from steam_aliases.txt)"
      [ -f "$CFG/steam_aliases.txt" ] && cat "$CFG/steam_aliases.txt"
    } > "$STAGE/akna-games.txt"

    # 3. Record hpo version
    hpo --version 2>/dev/null > "$STAGE/akna-version.txt" || echo "unknown" > "$STAGE/akna-version.txt"

    # 4. Pack it all into one tar.gz on the USB
    tar -czf "$TARGET/$BACKUP_NAME" -C "$STAGE" . || die "tar failed"
    SIZE=$(du -h "$TARGET/$BACKUP_NAME" | cut -f1)
    rm -rf "$STAGE"
    echo "AKNA_OK: saved $BACKUP_NAME ($SIZE) to $TARGET"
    ;;

  restore)
    [ -n "$TARGET" ] || die "no source given"
    ARCHIVE="$TARGET/$BACKUP_NAME"
    [ -f "$ARCHIVE" ] || die "no backup found at $ARCHIVE"

    rm -rf "$STAGE"; mkdir -p "$STAGE"
    tar -xzf "$ARCHIVE" -C "$STAGE" || die "extract failed"

    # Restore config
    mkdir -p "$CFG"
    cp -r "$STAGE/config/." "$CFG/" 2>/dev/null
    echo "AKNA_OK: hpo config restored to $CFG"
    echo ""
    echo "To reinstall your games, run:"
    echo "  hpo croc setup          (retro arcade)"
    echo "  hpo zhen install <alias>  (per Steam game)"
    echo ""
    echo "Your saved game list:"
    cat "$STAGE/akna-games.txt" 2>/dev/null
    rm -rf "$STAGE"
    ;;

  list)
    [ -n "$TARGET" ] || die "no source given"
    ARCHIVE="$TARGET/$BACKUP_NAME"
    [ -f "$ARCHIVE" ] || die "no backup found at $ARCHIVE"
    echo "AKNA_OK: backup contents ($ARCHIVE):"
    tar -tzf "$ARCHIVE"
    echo ""
    echo "Saved with hpo version:"
    tar -xzOf "$ARCHIVE" ./akna-version.txt 2>/dev/null || echo "unknown"
    ;;

  save-all)
    [ -n "$TARGET" ] || die "no destination given"
    [ -d "$TARGET" ] || die "destination not found: $TARGET"
    rm -rf "$STAGE"; mkdir -p "$STAGE/config" "$STAGE/carts"
    cp -r "$CFG/." "$STAGE/config/" 2>/dev/null
    {
      echo "# Akna full snapshot - $(date -Iseconds)"
      flatpak list --app --columns=application 2>/dev/null | sort -u
    } > "$STAGE/akna-games.txt"
    hpo --version 2>/dev/null > "$STAGE/akna-version.txt" || echo "unknown" > "$STAGE/akna-version.txt"
    # Copy each manga cart
    for c in "${CARTS[@]}"; do
      if [ -d "$HOME/$c" ]; then
        mkdir -p "$STAGE/carts/$(dirname "$c")"
        cp -r "$HOME/$c" "$STAGE/carts/$(dirname "$c")/" 2>/dev/null
        echo "  + cart: $c"
      fi
    done
    tar -czf "$TARGET/$BACKUP_ALL" -C "$STAGE" . || die "tar failed"
    SIZE=$(du -h "$TARGET/$BACKUP_ALL" | cut -f1)
    rm -rf "$STAGE"
    echo "AKNA_OK: saved $BACKUP_ALL ($SIZE) to $TARGET (config + carts)"
    ;;

  restore-all)
    [ -n "$TARGET" ] || die "no source given"
    ARCHIVE="$TARGET/$BACKUP_ALL"
    [ -f "$ARCHIVE" ] || die "no full backup found at $ARCHIVE"
    rm -rf "$STAGE"; mkdir -p "$STAGE"
    tar -xzf "$ARCHIVE" -C "$STAGE" || die "extract failed"
    mkdir -p "$CFG"
    cp -r "$STAGE/config/." "$CFG/" 2>/dev/null
    echo "AKNA_OK: config restored to $CFG"
    # Restore carts
    if [ -d "$STAGE/carts" ]; then
      cp -r "$STAGE/carts/." "$HOME/" 2>/dev/null
      echo "AKNA_OK: manga carts restored to ~/Documents and ~/Music"
    fi
    rm -rf "$STAGE"
    echo "Done! Rebuild carts with their build scripts if needed."
    ;;

  *)
    die "unknown action '$ACTION' (use: save | restore | list)"
    ;;
esac
