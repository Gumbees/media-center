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

    tmpfile="$(mktemp)"
    # BusyBox tar doesn't support -k; use plain extract and rely on correct permissions/user
    if tar -xvf "$tarfile" -C "$dir" >"$tmpfile" 2>&1; then
      while IFS= read -r line; do log "tar: $line"; done <"$tmpfile"
      rm -f "$tarfile"
      log "Done: $tarfile (removed)"
    else
      while IFS= read -r line; do log "tar: $line"; done <"$tmpfile"
      log "ERROR extracting $tarfile"
    fi
    rm -f "$tmpfile"
  done

  log "Sleeping 600s"
  sleep 600
done
