# SnappyMail webmail in one image: the official php Apache image, every PHP
# extension SnappyMail uses, and the SnappyMail release itself.
#
# - The release is checked with SnappyMail's release signing key.
# - Apache runs as www-data (uid/gid 82, as in Alpine images) on port 8080:
#   no process runs as root.
# - Data (settings, contacts, logs) lives in /var/lib/snappymail: mount it.
#
#   docker build --build-arg SNAPPYMAIL_VERSION=3.1.3 -t snappymail .

ARG PHP_IMAGE=php:8.6-apache

# ---- 1. Download the SnappyMail release and check its signature ------------
FROM debian:trixie-slim AS release

ARG SNAPPYMAIL_VERSION=3.1.3
# Fingerprint of the SnappyMail release key, as pinned in SnappyMail's own
# code (snappymail/v/*/app/libraries/snappymail/repository/signature.php).
ARG SNAPPYMAIL_KEY=1016E47079145542F8BA133548208BA13290F3EB

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && rm -rf /var/lib/apt/lists/*

# The key file shipped inside SnappyMail releases (sha1 pinned there too)
COPY keys/snappymail-releases.asc /tmp/releases.asc

RUN set -eu; \
    url="https://github.com/the-djmaze/snappymail/releases/download/v${SNAPPYMAIL_VERSION}/snappymail-${SNAPPYMAIL_VERSION}.tar.gz"; \
    curl -fsSL -o /tmp/snappymail.tar.gz "$url"; \
    curl -fsSL -o /tmp/snappymail.tar.gz.asc "$url.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --quiet --import /tmp/releases.asc; \
    gpg --batch --status-fd 3 --verify /tmp/snappymail.tar.gz.asc /tmp/snappymail.tar.gz 3>/tmp/gpg.status; \
    grep -q "^\[GNUPG:\] VALIDSIG ${SNAPPYMAIL_KEY} " /tmp/gpg.status \
      || { echo "SnappyMail ${SNAPPYMAIL_VERSION}: no valid signature by ${SNAPPYMAIL_KEY}" >&2; exit 1; }; \
    mkdir /app; \
    tar -xzf /tmp/snappymail.tar.gz -C /app; \
    test -d "/app/snappymail/v/${SNAPPYMAIL_VERSION}"; \
    # data lives outside the web root; drop the sample data folder and files
    rm -rf /app/data /app/_include.php /app/README.md; \
    printf '%s\n' '<?php' "define('APP_DATA_FOLDER_PATH', '/var/lib/snappymail/');" > /app/include.php

# ---- 2. The image -----------------------------------------------------------
FROM ${PHP_IMAGE}

ARG SNAPPYMAIL_VERSION=3.1.3
LABEL org.opencontainers.image.title="SnappyMail" \
      org.opencontainers.image.description="SnappyMail webmail on the official php Apache image" \
      org.opencontainers.image.version="${SNAPPYMAIL_VERSION}" \
      org.opencontainers.image.source="https://github.com/ebal/SnappyMail_Container" \
      org.opencontainers.image.licenses="AGPL-3.0-only"

COPY --from=mlocati/php-extension-installer:2.13.2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions intl gd zip tidy ldap mbstring \
 && rm /usr/local/bin/install-php-extensions

# PGP: SnappyMail runs the gpg program (it leaves the PECL gnupg extension
# switched off), so the image needs gpg and gpg-agent.
RUN apt-get update \
 && apt-get install -y --no-install-recommends gnupg \
 && rm -rf /var/lib/apt/lists/*

# www-data with uid/gid 82, so data folders from Alpine-based setups
# (djmaze/snappymail, php:*-alpine) keep working without a chown.
RUN groupmod -g 82 www-data \
 && usermod -u 82 -g 82 www-data \
 && mkdir -p /var/lib/snappymail \
 && chown -R www-data:www-data /var/lib/snappymail /var/run/apache2 /var/lock/apache2 /var/log/apache2

# Apache: only our site on port 8080, plus the modules SnappyMail's
# .htaccess files use and mod_remoteip for the real client address.
COPY config/apache.conf /etc/apache2/sites-available/snappymail.conf
RUN a2dissite -q 000-default \
 && a2ensite -q snappymail \
 && a2enmod -q rewrite headers expires remoteip \
 && sed -i 's/^Listen 80$/Listen 8080/; /Listen 443/d' /etc/apache2/ports.conf \
 && sed -i 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf

COPY config/php.ini /usr/local/etc/php/conf.d/zz-snappymail.ini
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# SnappyMail code belongs to root: the web server can read it, not change it.
COPY --from=release /app /var/www/html

ENV TZ=UTC
USER www-data
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -fsS -o /dev/null http://127.0.0.1:8080/ || exit 1
