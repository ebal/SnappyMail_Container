# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[unreleased]: https://github.com/ebal/SnappyMail_Container/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ebal/SnappyMail_Container/releases/tag/v1.0.0
