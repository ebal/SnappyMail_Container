#!/bin/bash
# Print a short hash of everything that decides what runs in an image:
# the Debian packages, the PHP version, every extension with its version,
# and the SnappyMail version. Two builds with the same fingerprint are the
# same for SnappyMail.
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
  dpkg-query -W -f "\${Package} \${Version}\n" | sort
  php -r "echo PHP_VERSION, PHP_EOL; foreach (get_loaded_extensions() as \$e) echo \$e, \" \", phpversion(\$e), PHP_EOL;"
  ls /var/www/html/snappymail/v
' | sha256sum | cut -c1-16
