#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

: "${FLYWAY_URL:?FLYWAY_URL must be set to a JDBC URL}"
: "${FLYWAY_USER:?FLYWAY_USER must be set}"
: "${FLYWAY_PASSWORD:?FLYWAY_PASSWORD must be set}"

migrations_dir="$(absolute_directory "${MIGRATIONS_DIR:-${repo_root}/database/migrations}")"
"${repo_root}/scripts/db/validate-migrations.sh" "$migrations_dir"
network="${FLYWAY_DOCKER_NETWORK:-host}"
image="${FLYWAY_IMAGE:-$FLYWAY_IMAGE_DEFAULT}"

export FLYWAY_CLEAN_DISABLED="${FLYWAY_CLEAN_DISABLED:-true}"
export FLYWAY_CONNECT_RETRIES="${FLYWAY_CONNECT_RETRIES:-10}"
export FLYWAY_CREATE_SCHEMAS="${FLYWAY_CREATE_SCHEMAS:-true}"
export FLYWAY_DEFAULT_SCHEMA="${FLYWAY_DEFAULT_SCHEMA:-public}"
export FLYWAY_LOCATIONS="filesystem:/flyway/sql"
export FLYWAY_LOCK_RETRY_COUNT="${FLYWAY_LOCK_RETRY_COUNT:-60}"
export FLYWAY_OUT_OF_ORDER="false"
export FLYWAY_PLACEHOLDER_REPLACEMENT="false"
export FLYWAY_SKIP_EXECUTING_MIGRATIONS="false"
export FLYWAY_SCHEMAS="${FLYWAY_SCHEMAS:-$FLYWAY_DEFAULT_SCHEMA}"
export FLYWAY_VALIDATE_MIGRATION_NAMING="true"
export FLYWAY_VALIDATE_ON_MIGRATE="true"

docker_args=(
  run --rm --network "$network"
  --volume "${migrations_dir}:/flyway/sql:ro"
)
for variable in \
  FLYWAY_CLEAN_DISABLED FLYWAY_CONNECT_RETRIES FLYWAY_CREATE_SCHEMAS \
  FLYWAY_DEFAULT_SCHEMA FLYWAY_INSTALLED_BY FLYWAY_LOCATIONS FLYWAY_LOCK_RETRY_COUNT \
  FLYWAY_OUT_OF_ORDER FLYWAY_PASSWORD FLYWAY_PLACEHOLDER_REPLACEMENT FLYWAY_SCHEMAS \
  FLYWAY_SKIP_EXECUTING_MIGRATIONS FLYWAY_URL FLYWAY_USER \
  FLYWAY_VALIDATE_MIGRATION_NAMING FLYWAY_VALIDATE_ON_MIGRATE; do
  [[ -n "${!variable:-}" ]] && docker_args+=(--env "$variable")
done

exec docker "${docker_args[@]}" "$image" "$@"
