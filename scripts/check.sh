#!/usr/bin/env bash
set -Eeuo pipefail

uv lock --check --project app/backend
uv run --project app/backend ruff format --check app/backend
uv run --project app/backend ruff check app/backend
uv run --project app/backend mypy app/backend/src
uv run --project app/backend pytest -c app/backend/pyproject.toml

pnpm --dir app/frontend format:check
pnpm --dir app/frontend test:ci
pnpm --dir app/frontend build

terraform fmt -check -recursive terraform
./scripts/db/validate-migrations.sh database/migrations
./scripts/db/test-contract.sh
uvx zizmor==1.30.0 .github/workflows
find scripts -name '*.sh' -print0 | xargs -0 bash -n
bash -n scripts/db/test-fixtures/docker
if command -v shellcheck >/dev/null 2>&1; then
  find scripts -name '*.sh' -print0 | xargs -0 shellcheck
  shellcheck scripts/db/test-fixtures/docker
fi
uvx check-jsonschema==0.38.0 --schemafile docs/release-manifest.schema.json \
  docs/examples/release-manifest.json
repo_root="$(pwd)"
TF_DATA_DIR="${repo_root}/.cache/terraform-check/bootstrap" \
  terraform -chdir=terraform/bootstrap init -backend=false -input=false >/dev/null
TF_DATA_DIR="${repo_root}/.cache/terraform-check/bootstrap" \
  terraform -chdir=terraform/bootstrap validate
TF_DATA_DIR="${repo_root}/.cache/terraform-check/live" \
  terraform -chdir=terraform/live init -backend=false -input=false >/dev/null
TF_DATA_DIR="${repo_root}/.cache/terraform-check/live" \
  terraform -chdir=terraform/live validate
