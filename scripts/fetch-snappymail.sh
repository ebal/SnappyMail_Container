#!/bin/sh
# Runs in the one-shot "fetch" service (alpine) on every "docker compose up".
#   - Downloads SNAPPYMAIL_VERSION into ./snappymail when that version is not
#     there yet, after checking SNAPPYMAIL_SHA256. Same version: nothing to do.
#   - Points SnappyMail's data folder to /var/lib/snappymail (include.php).
#   - Gives the data folder to the PHP user (www-data, uid 82 on Alpine).
set -eu

readonly APP=/app
readonly DATA=/data
readonly PHP_UID=82
readonly E_ARGS=64
readonly E_CHECKSUM=65

if [ -z "${SNAPPYMAIL_VERSION:-}" ] || [ -z "${SNAPPYMAIL_SHA256:-}" ]; then
  echo "SNAPPYMAIL_VERSION and SNAPPYMAIL_SHA256 must be set" >&2
  exit "$E_ARGS"
fi

if [ -f "$APP/snappymail/v/$SNAPPYMAIL_VERSION/include.php" ]; then
  echo "SnappyMail $SNAPPYMAIL_VERSION is already in place"
else
  echo "Downloading SnappyMail $SNAPPYMAIL_VERSION"
  tmp=$(mktemp -d)
  wget -q -O "$tmp/snappymail.tar.gz" \
    "https://github.com/the-djmaze/snappymail/releases/download/v${SNAPPYMAIL_VERSION}/snappymail-${SNAPPYMAIL_VERSION}.tar.gz"
  if ! echo "$SNAPPYMAIL_SHA256  $tmp/snappymail.tar.gz" | sha256sum -c -; then
    echo "Checksum of the download does not match SNAPPYMAIL_SHA256" >&2
    rm -rf "$tmp"
    exit "$E_CHECKSUM"
  fi
  mkdir "$tmp/new"
  tar -xzf "$tmp/snappymail.tar.gz" -C "$tmp/new"
  # The data folder lives outside the web root, so the bundled one is not needed.
  rm -rf "$tmp/new/data" "$tmp/new/README.md" "$tmp/new/_include.php"
  find "$APP" -mindepth 1 -delete
  cp -a "$tmp/new/." "$APP/"
  rm -rf "$tmp"
  echo "SnappyMail $SNAPPYMAIL_VERSION installed"
fi

cat > "$APP/include.php" <<'EOF'
<?php
// SnappyMail data (settings, domains, contacts, plugins, logs) lives outside
// the web root. Written by scripts/fetch-snappymail.sh.
define('APP_DATA_FOLDER_PATH', '/var/lib/snappymail/');
EOF
chown -R root:root "$APP"

chown -R "$PHP_UID:$PHP_UID" "$DATA"
chmod 0750 "$DATA"
echo "ready"
