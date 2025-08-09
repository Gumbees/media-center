#!/bin/sh

set -eu

: "${EXTRACTION_PATH:=/media/sabnzbd}"

log() {
  echo "[$(date)] $*"
}

while :; do
  log "Scan: $EXTRACTION_PATH (recursive)"
  count="$(find "$EXTRACTION_PATH" -type f -name '*.tar' 2>/dev/null | wc -l | tr -d ' ')"
  log "Found $count .tar file(s)"

  find "$EXTRACTION_PATH" -type f -name '*.tar' 2>/dev/null | while IFS= read -r tarfile; do
    dir=${tarfile%/*}
    log "Extracting: $tarfile -> $dir"
    # -k keeps existing files (skip overwrite) to avoid permission errors on files not owned by this user
    if tar -xvfk "$tarfile" -C "$dir" 2>&1 | while IFS= read -r line; do log "tar: $line"; done; then
      rm -f "$tarfile"
      log "Done: $tarfile (removed)"
    else
      log "ERROR extracting $tarfile"
    fi
  done

  log "Sleeping 600s"
  sleep 600
done
