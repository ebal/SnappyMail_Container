#!/bin/bash
# Start an image the way docker-compose.yml runs it (read-only, no Linux
# capabilities, empty data volume) and check that SnappyMail works.
# The publish workflow runs this before it pushes anything.
#
#   ci/smoke-test.sh IMAGE VERSION
#
# Exit status 0 means every check passed.

set -euo pipefail

readonly E_USAGE=64
readonly E_FAILED=1
readonly EXTENSIONS="intl gd zip apcu gnupg tidy ldap imagick pdo_sqlite sodium curl mbstring openssl"

if [ $# -ne 2 ]; then
  echo "usage: $0 IMAGE VERSION" >&2
  exit "$E_USAGE"
fi
image=$1
version=$2
name="snappymail-smoke-$$"
volume="snappymail-smoke-$$"
failed=0

# shellcheck disable=SC2329  # invoked by the EXIT trap
cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT

check() {  # check DESCRIPTION COMMAND...
  local description=$1
  shift
  if "$@"; then
    echo "ok   $description"
  else
    echo "FAIL $description"
    failed=1
  fi
}

in_container() {
  docker exec "$name" "$@"
}

status_of() {  # HTTP status of a path, fetched inside the container
  in_container curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8080$1"
}

docker run -d --name "$name" \
  --read-only --tmpfs /tmp --tmpfs /run/apache2 --tmpfs /run/lock \
  --cap-drop ALL --security-opt no-new-privileges:true \
  -v "$volume:/var/lib/snappymail" \
  "$image" >/dev/null

echo "== wait until healthy"
for _ in $(seq 1 30); do
  health=$(docker inspect -f '{{.State.Health.Status}}' "$name")
  [ "$health" = healthy ] && break
  [ "$(docker inspect -f '{{.State.Running}}' "$name")" = true ] || break
  sleep 2
done
check "container is healthy" [ "$health" = healthy ]

echo "== checks"
check "login page serves SnappyMail $version" \
  sh -c "docker exec $name curl -fsS http://127.0.0.1:8080/ | grep -q 'snappymail/v/$version/'"
check "admin page answers 200" [ "$(status_of '/?admin')" = 200 ]
check "code folder is blocked (403)" [ "$(status_of "/snappymail/v/$version/app/")" = 403 ]
check "no data folder in the web root" in_container test ! -e /var/www/html/data
# missing paths fall through to the login page, so check the body: no settings
check "settings file cannot be downloaded" \
  sh -c "! docker exec $name curl -s http://127.0.0.1:8080/data/_data_/_default_/configs/application.ini | grep -q '^\[webmail\]'"
check "apache runs as uid 82, not root" \
  sh -c "docker exec $name awk '/^Uid:/{exit (\$2==82 ? 0 : 1)}' /proc/1/status"
check "data folder is written (SnappyMail installed itself)" \
  in_container test -f /var/lib/snappymail/_data_/_default_/configs/application.ini
check "no version banner in the Server header" \
  sh -c "docker exec $name curl -sI http://127.0.0.1:8080/ | grep -qi '^Server: Apache\s*\$'"
for ext in $EXTENSIONS; do
  check "php extension $ext" in_container php -r "exit(extension_loaded('$ext') ? 0 : 1);"
done

if [ "$failed" -ne 0 ]; then
  echo "== container log"
  docker logs --tail 40 "$name" 2>&1
  exit "$E_FAILED"
fi
echo "== all checks passed"
