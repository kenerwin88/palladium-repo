#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
preview="${1:?usage: destroy-preview-schema.sh pr-N}"
[[ "$preview" =~ ^pr-([0-9]+)$ ]] || { echo "refusing to clean a non-preview schema" >&2; exit 64; }

export FLYWAY_SCHEMAS="pr_${BASH_REMATCH[1]}"
export FLYWAY_DEFAULT_SCHEMA="$FLYWAY_SCHEMAS"
export FLYWAY_CLEAN_DISABLED=false
"${repo_root}/scripts/db/flyway.sh" clean
