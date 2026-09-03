#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

: "${DATABASE_URL:?DATABASE_URL must be set for the disposable PostgreSQL database}"
output="${1:?usage: dump-schema.sh <output-file>}"
mkdir -p "$(dirname "$output")"

docker run --rm --network "${FLYWAY_DOCKER_NETWORK:-host}" \
  --env DATABASE_URL \
  "${POSTGRES_IMAGE:-$POSTGRES_IMAGE_DEFAULT}" \
  pg_dump "$DATABASE_URL" --schema-only --no-owner --no-privileges \
  | sed -E \
      -e '/^-- Dumped from database version /d' \
      -e '/^-- Dumped by pg_dump version /d' \
      -e '/^\\(un)?restrict /d' \
  >"$output"
