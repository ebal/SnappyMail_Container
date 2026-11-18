#!/bin/bash
# Use the valkey service as SnappyMail's cache, with SnappyMail's own
# "Cache Redis" plugin (it includes a PHP client, Predis, so PHP needs no
# redis extension). Run once, from the project folder, with the stack running:
#
#   scripts/enable-valkey-cache.sh
#
# The plugin is installed by SnappyMail's own installer, which checks the
# signature of the package. Safe to run again.

set -euo pipefail

readonly E_NODIR=66
readonly CONFIGS=/var/lib/snappymail/_data_/_default_/configs

cd "$(dirname "$0")/.." || exit "$E_NODIR"

php() {
  docker compose exec -T -u www-data php "$@"
}

echo "== install the Cache Redis plugin"
# shellcheck disable=SC2016  # PHP code: the $ signs are for PHP, not the shell
php php -r '
  $_ENV["SNAPPYMAIL_INCLUDE_AS_API"] = true;
  require "/var/www/html/index.php";
  echo \SnappyMail\Repository::installPackage("plugin", "cache-redis") ? "installed\n" : "install failed\n";
'

echo "== point it to valkey:6379"
php sh -c "printf '%s\n' '{\"plugin\":{\"host\":\"valkey\",\"port\":6379}}' > $CONFIGS/plugin-cache-redis.json"

echo "== enable plugins and this plugin"
php sh -c "sed -i \
  -e '/^\[plugins\]/,/^\[/ s/^enable = .*/enable = On/' \
  -e '/^\[plugins\]/,/^\[/ s/^enabled_list = .*/enabled_list = \"cache-redis\"/' \
  $CONFIGS/application.ini"

echo "== check: load the login page, then count keys in valkey"
docker compose exec -T nginx wget -q -O /dev/null http://127.0.0.1/
docker compose exec -T valkey valkey-cli dbsize
