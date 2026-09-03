#!/usr/bin/env bash

# shellcheck disable=SC2034 # Shared constants are consumed by scripts that source this file.
FLYWAY_IMAGE_DEFAULT="flyway/flyway:13.4.0@sha256:e19dbd5c73a1487d825ffe02f9e11e0ce3f37b80bbc012ece1cba15af4f9f9ce"
# shellcheck disable=SC2034 # Shared constants are consumed by scripts that source this file.
POSTGRES_IMAGE_DEFAULT="postgres:17.6-bookworm@sha256:f3bd19c606e442c3d7bdfa8002e03fe260a1023351e0ea4598032022b68dd6e3"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

absolute_path() {
  local path="$1"
  local directory
  directory="$(cd "$(dirname "$path")" && pwd -P)"
  printf '%s/%s\n' "$directory" "$(basename "$path")"
}

absolute_directory() {
  (cd "$1" && pwd -P)
}
