# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-11-20

### Changed

- **Breaking:** build one image, `3bal/snappymail`, with SnappyMail inside, on the official `php:8.6-apache` image. The `fetch` and `nginx` services are gone; the stack is `snappymail` and `valkey`.
- **Breaking:** run Apache as `www-data` with uid 82 on port 8080, so no process runs as root. Point a reverse proxy to port 8080.
- Check the SnappyMail download with the SnappyMail release key instead of a checksum.
- Build and publish the newest SnappyMail release every week, not only PHP and Debian updates.
- Test every image with `ci/smoke-test.sh` before it is published.
- Run both services read-only, without Linux capabilities, and with `no-new-privileges`.
- Pin the GitHub actions to commit hashes and give the workflow read access only.
- Install the `gpg` program for PGP, which SnappyMail uses instead of the `gnupg` extension.
- Install `mbstring`, which the `php:8.6-apache` image does not include.

### Removed

- Remove the PHP extensions `apcu`, `gnupg` and `imagick`: they do not build on PHP 8.6 yet, and SnappyMail works without them (Valkey cache, `gpg` program, `gd`).
- Remove the `fetch` and `nginx` services, `php/Dockerfile`, `config/nginx.conf`, `scripts/fetch-snappymail.sh` and `ci/rebuild.sh`.
- Remove the workflow step that kept the weekly schedule enabled: it needed write access to GitHub Actions.
- Stop copying the README to the Docker Hub page: it needs a token with delete rights. The Docker Hub token now needs Read & Write only.
- Stop publishing `3bal/snappymail-php`; the repository is deleted from Docker Hub. Use `3bal/snappymail`.

### Fixed

- Keep plugins that are already enabled when `scripts/enable-valkey-cache.sh` enables the cache.

### Security

- Build on PHP 8.6.0, which fixes CVE-2026-129474 (use-after-free in magic method backtraces, remote code execution) and CVE-2026-129182.

## [1.0.0] - 2026-11-19

### Added

- Run SnappyMail 3.1.3 with Docker Compose: official nginx and Valkey images, and a PHP image built from php:8.5-fpm-alpine.
- Add the PHP extensions intl, gd, zip, apcu, gnupg, tidy, ldap and imagick.
- Download SnappyMail at start and check its SHA-256; keep it on disk, read-only in the containers.
- Block SnappyMail's code and data folders in nginx, as its .htaccess files do for Apache.
- Use Valkey as the cache through SnappyMail's "Cache Redis" plugin (`scripts/enable-valkey-cache.sh`).
- Build the PHP image every week on GitHub Actions and publish it to Docker Hub only when its packages or versions changed.
- Rebuild locally with `ci/rebuild.sh`, which applies the new image only when it changed.
- Set the Valkey image tag with `VALKEY_IMAGE_TAG` in `.env` (default `9-alpine`).
- Copy the README to the Docker Hub page of the image when it changes.

[unreleased]: https://github.com/ebal/SnappyMail_Container/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/ebal/SnappyMail_Container/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/ebal/SnappyMail_Container/releases/tag/v1.0.0
