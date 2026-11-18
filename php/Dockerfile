# PHP-FPM for SnappyMail: the official php:8.5-fpm-alpine image plus the
# extensions SnappyMail can use. The weekly CI rebuilds it with --pull
# --no-cache, so PHP and Alpine security updates arrive within a week.
FROM php:8.5-fpm-alpine

COPY --from=mlocati/php-extension-installer:2.13.2 /usr/bin/install-php-extensions /usr/local/bin/

# intl: languages, gd + imagick: image thumbnails, zip: attachments as one
# archive, apcu: cache, gnupg: server-side PGP, tidy: HTML clean-up,
# ldap: LDAP address books
RUN install-php-extensions intl gd zip apcu gnupg tidy ldap imagick
