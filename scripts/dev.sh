#!/usr/bin/env bash
set -Eeuo pipefail

cleanup() {
  trap - EXIT INT TERM
  kill 0 2>/dev/null || true
}
trap cleanup EXIT INT TERM

uv run --project app/backend flask --app palladium:create_app run --debug --port 5000 &
pnpm --dir app/frontend start -- --proxy-config proxy.native.conf.json &
wait

