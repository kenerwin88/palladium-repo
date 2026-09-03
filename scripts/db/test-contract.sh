#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

mkdir -p "${temp_dir}/bin" "${temp_dir}/migrations"
cp "${repo_root}/scripts/db/test-fixtures/docker" "${temp_dir}/bin/docker"
cp "${repo_root}/database/migrations/V001__create_application_message.sql" \
  "${temp_dir}/migrations/"
chmod +x "${temp_dir}/bin/docker"

export FAKE_FLYWAY_STATE="${temp_dir}/flyway-state"
export FLYWAY_PASSWORD=test
export FLYWAY_URL=jdbc:postgresql://example.invalid/test
export FLYWAY_USER=test
export PATH="${temp_dir}/bin:${PATH}"
export SOURCE_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

"${repo_root}/scripts/db/plan.sh" test "${temp_dir}/migrations" \
  "${temp_dir}/plan.json" "${temp_dir}/plan.md"
jq -e '
  .schema_plan_version == "1.0" and
  .database.name == "testdb" and
  .database.schema == "public" and
  (.database.connection_fingerprint | test("^[0-9a-f]{64}$")) and
  .database.current_version == "empty" and
  (.pending | length == 1) and
  .pending[0].file == "V001__create_application_message.sql" and
  (.pending[0].sha256 | test("^[0-9a-f]{64}$"))
' "${temp_dir}/plan.json" >/dev/null
grep -F 'CREATE TABLE application_message' "${temp_dir}/plan.md" >/dev/null

"${repo_root}/scripts/db/apply-plan.sh" test "${temp_dir}/migrations" \
  "${temp_dir}/plan.json" "${temp_dir}/receipt.json"
jq -e '
  .schema_deployment_version == "1.0" and
  .before.schema_version == "empty" and
  .after.schema_version == "001" and
  (.applied | length == 1)
' "${temp_dir}/receipt.json" >/dev/null

rm "$FAKE_FLYWAY_STATE"
"${repo_root}/scripts/db/plan.sh" test "${temp_dir}/migrations" \
  "${temp_dir}/tamper-plan.json" "${temp_dir}/tamper-plan.md"
printf '\n-- changed after review\n' >>"${temp_dir}/migrations/V001__create_application_message.sql"
if "${repo_root}/scripts/db/apply-plan.sh" test "${temp_dir}/migrations" \
  "${temp_dir}/tamper-plan.json" "${temp_dir}/tamper-receipt.json" >/dev/null 2>&1; then
  echo "tampered migration unexpectedly passed the reviewed-plan guard" >&2
  exit 1
fi
