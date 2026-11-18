#!/bin/bash
# Print a short hash of everything that decides what runs in a php image:
# the Alpine packages, the PHP version and every extension with its version.
# Two builds with the same fingerprint are the same for SnappyMail.
#
#   ci/fingerprint.sh IMAGE

set -euo pipefail

readonly E_USAGE=64

if [ $# -ne 1 ]; then
  echo "usage: $0 IMAGE" >&2
  exit "$E_USAGE"
fi

# shellcheck disable=SC2016  # the $ signs belong to the shell and PHP inside the container
docker run --rm --entrypoint sh "$1" -c '
  apk info -v 2>/dev/null | sort
  php -r "echo PHP_VERSION, PHP_EOL; foreach (get_loaded_extensions() as \$e) echo \$e, \" \", phpversion(\$e), PHP_EOL;"
' | sha256sum | cut -c1-16
