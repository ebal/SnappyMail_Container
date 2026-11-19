#!/bin/bash
# Use the valkey service as SnappyMail's cache, with SnappyMail's own
# "Cache Redis" plugin (it includes a PHP client, Predis, so PHP needs no
# redis extension). Run once, from the project folder, with the stack running:
#
#   scripts/enable-valkey-cache.sh
#
# The plugin is installed by SnappyMail's own installer, which checks the
# signature of the package. Plugins that are already enabled stay enabled.
# Safe to run again.

set -euo pipefail

readonly E_NODIR=66
readonly CONFIGS=/var/lib/snappymail/_data_/_default_/configs

cd "$(dirname "$0")/.." || exit "$E_NODIR"

app() {
  docker compose exec -T snappymail "$@"
}

echo "== install the Cache Redis plugin"
# shellcheck disable=SC2016  # PHP code: the $ signs are for PHP, not the shell
app php -r '
  $_ENV["SNAPPYMAIL_INCLUDE_AS_API"] = true;
  require "/var/www/html/index.php";
  echo \SnappyMail\Repository::installPackage("plugin", "cache-redis") ? "installed\n" : "install failed\n";
'

echo "== point it to valkey:6379"
app sh -c "printf '%s\n' '{\"plugin\":{\"host\":\"valkey\",\"port\":6379}}' > $CONFIGS/plugin-cache-redis.json"

echo "== enable plugins, and add cache-redis to the enabled plugins"
# shellcheck disable=SC2016  # PHP code: the $ signs are for PHP, not the shell
app php -r '
  $f = "'"$CONFIGS"'/application.ini";
  $ini = file_get_contents($f);
  $ini = preg_replace("/^(\[plugins\][^\[]*?^enable = ).*$/ms", "\${1}On", $ini, 1);
  if (preg_match("/^(\[plugins\][^\[]*?^enabled_list = \")([^\"]*)\"/ms", $ini, $m)) {
    $list = array_filter(explode(",", $m[2]));
    if (!in_array("cache-redis", $list)) $list[] = "cache-redis";
    $ini = str_replace($m[0], $m[1] . implode(",", $list) . "\"", $ini);
  }
  file_put_contents($f, $ini);
  preg_match("/^enabled_list = .*$/m", $ini, $m); echo $m[0], "\n";
'

echo "== check: load the login page, then count keys in valkey"
app curl -fsS -o /dev/null http://127.0.0.1:8080/
docker compose exec -T valkey valkey-cli dbsize
