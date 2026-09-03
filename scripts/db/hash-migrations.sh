#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# shellcheck source=scripts/db/common.sh
source "${repo_root}/scripts/db/common.sh"

migrations_dir="$(absolute_directory "${1:?usage: hash-migrations.sh <migrations-directory>}")"
"${repo_root}/scripts/db/validate-migrations.sh" "$migrations_dir"
while IFS= read -r file; do
  printf '%s  %s\n' "$(sha256_file "$file")" "$(basename "$file")"
done < <(find "$migrations_dir" -maxdepth 1 -type f -name 'V*__*.sql' | LC_ALL=C sort -V) \
  | sha256_stdin
