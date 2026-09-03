#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

base_sha="${1:?usage: ci-proof.sh <base-sha> <output-directory>}"
output_directory="${2:?usage: ci-proof.sh <base-sha> <output-directory>}"
[[ "$base_sha" =~ ^[0-9a-f]{40}$ ]] || { echo "base SHA must be a full Git SHA" >&2; exit 64; }
mkdir -p "$output_directory"
output_directory="$(absolute_directory "$output_directory")"

temp_dir="$(mktemp -d)"
trap 'status=$?; echo "Database rehearsal failed at ci-proof.sh:${LINENO} (exit ${status})." >&2; exit "$status"' ERR
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "${temp_dir}/base-migrations"
if git -C "$repo_root" cat-file -e "${base_sha}:database/migrations" 2>/dev/null; then
  git -C "$repo_root" archive "$base_sha" database/migrations \
    | tar -x -C "$temp_dir"
  mv "${temp_dir}/database/migrations"/* "${temp_dir}/base-migrations/"
fi

if find "${temp_dir}/base-migrations" -maxdepth 1 -type f -name 'V*__*.sql' | grep -q .; then
  echo "Rebuilding the merge-base schema..." >&2
  MIGRATIONS_DIR="${temp_dir}/base-migrations" "${repo_root}/scripts/db/flyway.sh" migrate
fi

echo "Capturing the merge-base schema..." >&2
"${repo_root}/scripts/db/dump-schema.sh" "${temp_dir}/before.sql"
echo "Generating the proposed migration plan..." >&2
"${repo_root}/scripts/db/plan.sh" pull-request "${repo_root}/database/migrations" \
  "${output_directory}/schema-plan.json" "${output_directory}/schema-plan.md"
echo "Applying the reviewed plan to disposable PostgreSQL..." >&2
"${repo_root}/scripts/db/apply-plan.sh" pull-request "${repo_root}/database/migrations" \
  "${output_directory}/schema-plan.json" "${output_directory}/schema-deployment.json"
echo "Capturing and comparing the proposed schema..." >&2
"${repo_root}/scripts/db/dump-schema.sh" "${temp_dir}/after.sql"

diff -u --label merge-base-schema.sql --label proposed-schema.sql \
  "${temp_dir}/before.sql" "${temp_dir}/after.sql" >"${output_directory}/schema.diff" || true

{
  echo
  echo "<details><summary>Rehearsed PostgreSQL schema diff</summary>"
  echo
  echo '```diff'
  # shellcheck disable=SC2016 # Literal backticks neutralize nested Markdown fences.
  sed 's/```/` ` `/g' "${output_directory}/schema.diff"
  echo '```'
  echo
  echo "</details>"
  echo
  echo "> Rehearsal executed every pending migration against disposable PostgreSQL built from the merge base. Data-dependent behavior still requires representative test data."
} >>"${output_directory}/schema-plan.md"

jq -n \
  --arg base_sha "$base_sha" \
  --arg plan_sha256 "$(sha256_file "${output_directory}/schema-plan.json")" \
  --arg deployment_record_sha256 "$(sha256_file "${output_directory}/schema-deployment.json")" \
  --arg schema_diff_sha256 "$(sha256_file "${output_directory}/schema.diff")" \
  '{
    rehearsal_version: "1.0",
    merge_base_git_sha: $base_sha,
    succeeded: true,
    plan_sha256: $plan_sha256,
    deployment_record_sha256: $deployment_record_sha256,
    schema_diff_sha256: $schema_diff_sha256
  }' >"${output_directory}/schema-rehearsal.json"

echo "Database rehearsal proof is complete." >&2
