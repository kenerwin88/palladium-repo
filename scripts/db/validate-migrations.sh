#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

migrations_dir="$(absolute_directory "${1:?usage: validate-migrations.sh <migrations-directory>}")"
count=0
while IFS= read -r -d '' entry; do
  name="$(basename "$entry")"
  [[ -f "$entry" && ! -L "$entry" ]] || {
    echo "migration directory may contain only regular SQL files: ${name}" >&2
    exit 1
  }
  [[ "$name" =~ ^V[0-9]{3}__[a-z0-9_]+\.sql$ ]] || {
    echo "invalid migration name ${name}; expected V001__lower_snake_case.sql" >&2
    exit 1
  }
  count=$((count + 1))
done < <(find "$migrations_dir" -mindepth 1 -maxdepth 1 -print0)

((count > 0)) || { echo "at least one versioned SQL migration is required" >&2; exit 1; }
