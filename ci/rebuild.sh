#!/bin/bash
# Rebuild the php image on this host and apply it only if it changed.
#
# 1. Build php/ again with --pull --no-cache: newest php:8.5-fpm-alpine and
#    newest Alpine packages for the extensions.
# 2. Compare its fingerprint (ci/fingerprint.sh) with the image in use.
#    Replace the image only if they differ.
# 3. Pull the official images (nginx, valkey, alpine), then "docker compose up":
#    only containers whose image changed are recreated.
#
#   ci/rebuild.sh            run it from any folder
#   FORCE=1 ci/rebuild.sh    use the new php image even if nothing changed
#
# Hosts that pull a published image (SNAPPYMAIL_PHP_IMAGE in .env) do not need
# this script: "docker compose pull && docker compose up -d" is enough.

set -euo pipefail

readonly E_NODIR=66
readonly CANDIDATE=snappymail-php:candidate

cd "$(dirname "$0")/.." || exit "$E_NODIR"

# the image name the php service uses (from docker-compose.yml and .env)
image=$(docker compose config --format json \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["services"]["php"]["image"])')

echo "== build $CANDIDATE"
docker build --pull --no-cache -q -t "$CANDIDATE" php >/dev/null

new=$(ci/fingerprint.sh "$CANDIDATE")
old=$(ci/fingerprint.sh "$image" 2>/dev/null || echo "none")
php_version=$(docker run --rm --entrypoint php "$CANDIDATE" -r 'echo PHP_VERSION;')
echo "php $php_version, fingerprint new=$new in use=$old ($image)"

if [ "$new" != "$old" ] || [ "${FORCE:-0}" = "1" ]; then
  echo "== php image changed: use it"
  docker tag "$CANDIDATE" "$image"
else
  echo "== php image unchanged"
fi
docker rmi "$CANDIDATE" >/dev/null

echo "== pull official images"
docker compose pull --ignore-buildable --quiet

echo "== apply"
docker compose up -d --no-build --wait --wait-timeout 180
docker image prune -f >/dev/null

docker compose ps --format '{{.Service}}: {{.Image}} {{.Status}}'
