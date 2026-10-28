#!/usr/bin/env bash
# Independent, versioned backup of the live quickshell-dots bar directory.
#
# Why this exists: qs-shell-apply-update.sh (the bar's own self-updater)
# replaces ~/.config/quickshell/bar/ wholesale with a fresh copy from the
# upstream repo on "apply update" — wiping any local customizations. It
# does keep its own backup (~/.local/state/qs-shell/backups/), but only the
# last 3, and it's a plain timestamped copy with no history/diff.
#
# This script instead mirrors the bar directory into its own independent
# git repo, so customizations always have full history and are never lost
# to that rotation, regardless of what the self-updater does.
#
# Usage: run any time after customizing the bar (or on a schedule) to take
# a new snapshot. No-ops (no commit) if nothing changed since the last run.

set -euo pipefail

SRC="$HOME/.config/quickshell/bar/"
DEST="$HOME/.local/state/quickshell-bar-backup"

mkdir -p "$DEST"
if [ ! -d "$DEST/.git" ]; then
  git -C "$DEST" init -q
  git -C "$DEST" config user.name "quickshell-bar-backup"
  git -C "$DEST" config user.email "backup@localhost"
fi

rsync -a --delete --exclude=.git "$SRC" "$DEST/"

git -C "$DEST" add -A
if git -C "$DEST" diff --cached --quiet; then
  echo "qs-bar-backup-snapshot: no changes since last snapshot"
  exit 0
fi

git -C "$DEST" commit -q -m "Snapshot $(date -Iseconds)"
echo "qs-bar-backup-snapshot: committed $(git -C "$DEST" rev-parse --short HEAD)"
