#!/bin/bash
# Copies the tracked Obsidian settings into every registered vault that has
# opted in with a .obsidian-managed marker file. Notes are never touched - only
# .obsidian/ config files and the vimrc at the vault root.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER=".obsidian-managed"

case "$(uname -s)" in
    Darwin) REGISTRY="$HOME/Library/Application Support/obsidian/obsidian.json" ;;
    *)      REGISTRY="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json" ;;
esac

if [[ ! -f "$REGISTRY" ]]; then
    echo "Obsidian not set up on this machine, skipping config"
    exit 0
fi

if ! command -v jq &>/dev/null; then
    echo "jq not found, skipping Obsidian config" >&2
    exit 0
fi

if pgrep -x Obsidian &>/dev/null; then
    echo "Obsidian is running - it may overwrite these files on quit." >&2
    echo "Quit Obsidian and re-run this script if settings do not stick." >&2
fi

vaults="$(jq -r '.vaults[].path' "$REGISTRY")"
if [[ -z "$vaults" ]]; then
    echo "No Obsidian vaults registered, skipping config"
    exit 0
fi

while IFS= read -r vault; do
    if [[ ! -d "$vault" ]]; then
        echo "Vault not on disk, skipping: $vault" >&2
        continue
    fi

    # Opt-in per vault. A work vault must never be reconfigured by accident.
    if [[ ! -f "$vault/$MARKER" ]]; then
        echo "Not managed, skipping: $vault" >&2
        echo "  to manage it: touch \"$vault/$MARKER\"" >&2
        continue
    fi

    echo "Applying Obsidian config to $vault"
    mkdir -p "$vault/.obsidian"
    cp -R "$SRC_DIR/config/." "$vault/.obsidian/"
    cp "$SRC_DIR/obsidian.vimrc" "$vault/.obsidian.vimrc"

    missing=()
    while IFS= read -r plugin; do
        [[ -f "$vault/.obsidian/plugins/$plugin/manifest.json" ]] || missing+=("$plugin")
    done < <(jq -r '.[]' "$SRC_DIR/config/community-plugins.json")

    if (( ${#missing[@]} )); then
        echo "  install from Obsidian's community plugin browser: ${missing[*]}"
    fi
done <<< "$vaults"
