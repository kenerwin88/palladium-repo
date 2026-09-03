#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

environment="${1:?usage: apply-plan.sh <environment> <migrations-dir> <reviewed-plan> <deployment-record>}"
migrations_dir="${2:?usage: apply-plan.sh <environment> <migrations-dir> <reviewed-plan> <deployment-record>}"
reviewed_plan="${3:?usage: apply-plan.sh <environment> <migrations-dir> <reviewed-plan> <deployment-record>}"
deployment_record="${4:?usage: apply-plan.sh <environment> <migrations-dir> <reviewed-plan> <deployment-record>}"

[[ "$environment" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "invalid environment" >&2; exit 64; }
migrations_dir="$(absolute_directory "$migrations_dir")"
reviewed_plan="$(absolute_path "$reviewed_plan")"
mkdir -p "$(dirname "$deployment_record")"
deployment_record="$(absolute_path "$deployment_record")"

jq -e --arg environment "$environment" '
  .schema_plan_version == "1.0" and
  .environment == $environment and
  (.source.git_sha | test("^[0-9a-f]{40}$")) and
  (.database.name | length > 0) and
  (.database.schema | length > 0) and
  (.database.connection_fingerprint | test("^[0-9a-f]{64}$")) and
  (.database.history_fingerprint | test("^[0-9a-f]{64}$")) and
  (.migration_set_sha256 | test("^[0-9a-f]{64}$")) and
  (.pending | type == "array")
' "$reviewed_plan" >/dev/null

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
SOURCE_SHA="$(jq -r '.source.git_sha' "$reviewed_plan")"
export SOURCE_SHA
"${repo_root}/scripts/db/plan.sh" "$environment" "$migrations_dir" \
  "${temp_dir}/current-plan.json" "${temp_dir}/current-plan.md"

jq -cS '{environment, source: .source.git_sha, database, migration_set_sha256, pending}' \
  "$reviewed_plan" >"${temp_dir}/reviewed-contract.json"
jq -cS '{environment, source: .source.git_sha, database, migration_set_sha256, pending}' \
  "${temp_dir}/current-plan.json" >"${temp_dir}/current-contract.json"
if ! cmp -s "${temp_dir}/reviewed-contract.json" "${temp_dir}/current-contract.json"; then
  echo "database changed after the reviewed migration plan; refusing to migrate" >&2
  diff -u "${temp_dir}/reviewed-contract.json" "${temp_dir}/current-contract.json" || true
  exit 1
fi

plan_sha256="$(sha256_file "$reviewed_plan")"
before_version="$(jq -r '.database.current_version' "$reviewed_plan")"
before_fingerprint="$(jq -r '.database.history_fingerprint' "$reviewed_plan")"
migration_set_sha256="$(jq -r '.migration_set_sha256' "$reviewed_plan")"

export FLYWAY_INSTALLED_BY="${FLYWAY_INSTALLED_BY:-github:${GITHUB_ACTOR:-local}:run-${GITHUB_RUN_ID:-local}-a${GITHUB_RUN_ATTEMPT:-local}}"
if ! MIGRATIONS_DIR="$migrations_dir" "${repo_root}/scripts/db/flyway.sh" migrate -outputType=json \
  >"${temp_dir}/migrate.json"; then
  echo "Flyway migration failed:" >&2
  cat "${temp_dir}/migrate.json" >&2
  exit 1
fi
if ! MIGRATIONS_DIR="$migrations_dir" "${repo_root}/scripts/db/flyway.sh" validate -outputType=json \
  >"${temp_dir}/validate.json"; then
  echo "Flyway validation failed after migration:" >&2
  cat "${temp_dir}/validate.json" >&2
  exit 1
fi
"${repo_root}/scripts/db/plan.sh" "$environment" "$migrations_dir" \
  "${temp_dir}/after-plan.json" "${temp_dir}/after-plan.md"
jq -e '.pending | length == 0' "${temp_dir}/after-plan.json" >/dev/null

applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
after_version="$(jq -r '.database.current_version' "${temp_dir}/after-plan.json")"
after_fingerprint="$(jq -r '.database.history_fingerprint' "${temp_dir}/after-plan.json")"
jq -n \
  --arg environment "$environment" \
  --arg applied_at "$applied_at" \
  --arg actor "${GITHUB_ACTOR:-local}" \
  --arg change_record "${CHANGE_RECORD:-}" \
  --arg run_id "${GITHUB_RUN_ID:-local}" \
  --arg run_attempt "${GITHUB_RUN_ATTEMPT:-local}" \
  --arg plan_sha256 "$plan_sha256" \
  --arg migration_set_sha256 "$migration_set_sha256" \
  --arg before_version "$before_version" \
  --arg before_fingerprint "$before_fingerprint" \
  --arg after_version "$after_version" \
  --arg after_fingerprint "$after_fingerprint" \
  --argjson applied "$(jq '.pending' "$reviewed_plan")" \
  '{
    schema_deployment_version: "1.0",
    environment: $environment,
    applied_at: $applied_at,
    actor: $actor,
    change_record: $change_record,
    run: {id: $run_id, attempt: $run_attempt},
    reviewed_plan_sha256: $plan_sha256,
    migration_set_sha256: $migration_set_sha256,
    before: {schema_version: $before_version, history_fingerprint: $before_fingerprint},
    after: {schema_version: $after_version, history_fingerprint: $after_fingerprint},
    applied: $applied
  }' >"$deployment_record"
record_sha256="$(sha256_file "$deployment_record")"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Database migration applied: ${environment}"
    echo
    echo "- Schema version: \`${before_version}\` -> \`${after_version}\`"
    echo "- Reviewed plan SHA-256: \`${plan_sha256}\`"
    echo "- Deployment record SHA-256: \`${record_sha256}\`"
    echo "- Applied migrations: \`$(jq '.applied | length' "$deployment_record")\`"
  } >>"$GITHUB_STEP_SUMMARY"
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "migration_set_sha256=${migration_set_sha256}"
    echo "plan_sha256=${plan_sha256}"
    echo "record_sha256=${record_sha256}"
    echo "schema_version=${after_version}"
  } >>"$GITHUB_OUTPUT"
fi
