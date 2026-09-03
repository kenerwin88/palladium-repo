#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

environment="${1:?usage: plan.sh <environment> <migrations-dir> <json-plan> <markdown-plan>}"
migrations_dir="${2:?usage: plan.sh <environment> <migrations-dir> <json-plan> <markdown-plan>}"
json_plan="${3:?usage: plan.sh <environment> <migrations-dir> <json-plan> <markdown-plan>}"
markdown_plan="${4:?usage: plan.sh <environment> <migrations-dir> <json-plan> <markdown-plan>}"

[[ "$environment" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "invalid environment" >&2; exit 64; }
migrations_dir="$(absolute_directory "$migrations_dir")"
mkdir -p "$(dirname "$json_plan")" "$(dirname "$markdown_plan")"
json_plan="$(absolute_path "$json_plan")"
markdown_plan="$(absolute_path "$markdown_plan")"

source_sha="${SOURCE_SHA:-$(git -C "$repo_root" rev-parse HEAD)}"
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo "SOURCE_SHA must be a full Git SHA" >&2; exit 64; }
run_id="${RUN_ID:-local}"
run_attempt="${RUN_ATTEMPT:-local}"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

if ! MIGRATIONS_DIR="$migrations_dir" "${repo_root}/scripts/db/flyway.sh" validate -outputType=json \
  >"${temp_dir}/validate.json"; then
  echo "Flyway validation failed:" >&2
  cat "${temp_dir}/validate.json" >&2
  exit 1
fi
if ! MIGRATIONS_DIR="$migrations_dir" "${repo_root}/scripts/db/flyway.sh" info -outputType=json \
  >"${temp_dir}/info.json"; then
  echo "Flyway info failed:" >&2
  cat "${temp_dir}/info.json" >&2
  exit 1
fi
jq -e '.migrations | type == "array"' "${temp_dir}/info.json" >/dev/null
echo "Flyway state captured for ${environment}." >&2

files_json="${temp_dir}/files.json"
: >"${temp_dir}/files.ndjson"
while IFS= read -r file; do
  basename="$(basename "$file")"
  hash="$(sha256_file "$file")"
  jq -cn --arg file "$basename" --arg sha256 "$hash" '{file: $file, sha256: $sha256}' \
    >>"${temp_dir}/files.ndjson"
done < <(find "$migrations_dir" -maxdepth 1 -type f -name 'V*__*.sql' | LC_ALL=C sort -V)
jq -s '.' "${temp_dir}/files.ndjson" >"$files_json"
echo "Migration files hashed for ${environment}." >&2

migration_set_sha256="$("${repo_root}/scripts/db/hash-migrations.sh" "$migrations_dir")"
connection_fingerprint="$(printf '%s' "$FLYWAY_URL" | sha256_stdin)"

history_json="$(jq -cS '[.migrations[] |
  select((.state | ascii_downcase) != "pending" and (.state | ascii_downcase) != "outdated") |
  {category, description, installedOnUTC, state, type, version}]' "${temp_dir}/info.json")"
history_fingerprint="$(printf '%s' "$history_json" | sha256_stdin)"
echo "Schema history fingerprinted for ${environment}." >&2

jq --argjson files "$(cat "$files_json")" '
  [ .migrations[]
    | select((.state | ascii_downcase) == "pending" or (.state | ascii_downcase) == "outdated")
    | . as $migration
    | (($migration.filepath // "") | gsub("\\\\"; "/") | split("/") | last) as $name
    | ($files[] | select(.file == $name)) as $file
    | {
        category: $migration.category,
        description: $migration.description,
        file: $file.file,
        sha256: $file.sha256,
        state: $migration.state,
        type: $migration.type,
        version: ($migration.version // "")
      }
  ]' "${temp_dir}/info.json" >"${temp_dir}/pending.json"
echo "Pending migrations resolved for ${environment}." >&2

flyway_pending_count="$(jq '[.migrations[] | select((.state | ascii_downcase) == "pending" or (.state | ascii_downcase) == "outdated")] | length' "${temp_dir}/info.json")"
resolved_pending_count="$(jq 'length' "${temp_dir}/pending.json")"
[[ "$flyway_pending_count" == "$resolved_pending_count" ]] || {
  echo "could not match every pending Flyway migration to a reviewed SQL file" >&2
  exit 1
}
echo "Flyway and reviewed-file counts agree for ${environment}." >&2

jq -n \
  --arg environment "$environment" \
  --arg source_sha "$source_sha" \
  --arg run_id "$run_id" \
  --arg run_attempt "$run_attempt" \
  --arg generated_at "$generated_at" \
  --arg flyway_image "${FLYWAY_IMAGE:-$FLYWAY_IMAGE_DEFAULT}" \
  --arg database_name "$(jq -r '.database // "unknown"' "${temp_dir}/info.json")" \
  --arg database_schema "$(jq -r '.schemaName // "unknown"' "${temp_dir}/info.json")" \
  --arg current_version "$(jq -r '.schemaVersion // "empty"' "${temp_dir}/info.json")" \
  --arg connection_fingerprint "$connection_fingerprint" \
  --arg history_fingerprint "$history_fingerprint" \
  --arg migration_set_sha256 "$migration_set_sha256" \
  --argjson migrations "$(cat "$files_json")" \
  --argjson pending "$(cat "${temp_dir}/pending.json")" \
  '{
    schema_plan_version: "1.0",
    environment: $environment,
    generated_at: $generated_at,
    source: {git_sha: $source_sha, run_id: $run_id, run_attempt: $run_attempt},
    tool: {name: "Flyway Community", image: $flyway_image},
    database: {
      name: $database_name,
      schema: $database_schema,
      connection_fingerprint: $connection_fingerprint,
      current_version: $current_version,
      history_fingerprint: $history_fingerprint
    },
    migration_set_sha256: $migration_set_sha256,
    migrations: $migrations,
    pending: $pending
  }' >"$json_plan"
echo "Machine-readable migration plan rendered for ${environment}." >&2

plan_sha256="$(sha256_file "$json_plan")"
printf '%s  %s\n' "$plan_sha256" "$(basename "$json_plan")" >"${json_plan}.sha256"

{
  echo "### Database migration plan: ${environment}"
  echo
  echo "This is a Flyway Community review bundle, not the licensed Flyway dry-run feature."
  echo
  echo "- Target database: \`$(jq -r '.database.name' "$json_plan")\`"
  echo "- Target schema: \`$(jq -r '.database.schema' "$json_plan")\`"
  echo "- Connection fingerprint: \`${connection_fingerprint}\`"
  echo "- Current schema version: \`$(jq -r '.database.current_version' "$json_plan")\`"
  echo "- Pending migrations: \`$(jq '.pending | length' "$json_plan")\`"
  echo "- Schema-history fingerprint: \`${history_fingerprint}\`"
  echo "- Migration-set SHA-256: \`${migration_set_sha256}\`"
  echo "- Plan SHA-256: \`${plan_sha256}\`"
  echo
  echo "| Version | State | File | SHA-256 |"
  echo "|---|---|---|---|"
  if [[ "$resolved_pending_count" == 0 ]]; then
    echo "| — | Current | No pending migrations | — |"
  else
    jq -r '.pending[] | "| `\(.version)` | \(.state) | `\(.file)` | `\(.sha256)` |"' "$json_plan"
  fi
  echo
  echo "<details><summary>Exact pending SQL, in Flyway order</summary>"
  echo
  while IFS= read -r file; do
    echo "#### \`${file}\`"
    echo
    echo '```sql'
    # shellcheck disable=SC2016 # Literal backticks neutralize nested Markdown fences.
    sed 's/```/` ` `/g' "${migrations_dir}/${file}"
    echo '```'
    echo
  done < <(jq -r '.pending[].file' "$json_plan")
  echo "</details>"
} >"$markdown_plan"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "current_version=$(jq -r '.database.current_version' "$json_plan")"
    echo "migration_set_sha256=${migration_set_sha256}"
    echo "pending_count=${resolved_pending_count}"
    echo "plan_sha256=${plan_sha256}"
  } >>"$GITHUB_OUTPUT"
fi
