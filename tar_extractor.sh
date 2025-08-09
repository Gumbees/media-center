#!/bin/sh

set -eu

: "${EXTRACTION_PATH:=/media/sabnzbd}"

log() {
  echo "[$(date)] $*"
}

extract_one() {
  tarfile="$1"
  dir=${tarfile%/*}
  case "$tarfile" in
    *.tar|*.TAR)
      flags="-xvf"
      ;;
    *.tar.gz|*.tgz|*.TAR.GZ|*.TGZ)
      flags="-xzvf"
      ;;
    *)
      log "Skip (unsupported extension): $tarfile"
      return 0
      ;;
  esac

  log "Extracting: $tarfile -> $dir"
  tmpfile="$(mktemp)"
  if tar $flags "$tarfile" -C "$dir" >"$tmpfile" 2>&1; then
    while IFS= read -r line; do log "tar: $line"; done <"$tmpfile"
    rm -f "$tarfile"
    log "Done: $tarfile (removed)"
  else
    while IFS= read -r line; do log "tar: $line"; done <"$tmpfile"
    log "ERROR extracting $tarfile"
  fi
  rm -f "$tmpfile"
}

while :; do
  log "Scan: $EXTRACTION_PATH (recursive)"
  count="$(find "$EXTRACTION_PATH" -type f \( -iname '*.tar' -o -iname '*.tar.gz' -o -iname '*.tgz' \) 2>/dev/null | wc -l | tr -d ' ')"
  log "Found $count archive(s) (.tar, .tar.gz, .tgz)"

  find "$EXTRACTION_PATH" -type f \( -iname '*.tar' -o -iname '*.tar.gz' -o -iname '*.tgz' \) 2>/dev/null |
    while IFS= read -r tarfile; do
      extract_one "$tarfile"
    done

  log "Sleeping 600s"
  sleep 600
done
