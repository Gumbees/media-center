#!/bin/sh

set -eu

: "${EXTRACTION_PATH:=/media/sabnzbd}"

while :; do
  echo "Starting tar extraction at $(date)"
  # Use POSIX sh-friendly loop; handle no-match case safely
  for tarfile in "$EXTRACTION_PATH"/*.tar; do
    [ -e "$tarfile" ] || continue
    dir=${tarfile%/*}
    echo "Extracting: $tarfile into $dir"
    if tar -xf "$tarfile" -C "$dir"; then
      rm -f "$tarfile"
      echo "Successfully extracted and removed $tarfile"
    else
      echo "Failed to extract $tarfile"
    fi
  done
  echo "Extraction complete, sleeping for 10 minutes"
  sleep 600
done
