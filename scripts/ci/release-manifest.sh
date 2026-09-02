#!/usr/bin/env bash
set -Eeuo pipefail

for name in VERSION SOURCE_SHA RUN_ID RUN_ATTEMPT DELIVERY_RUN_ID DELIVERY_RUN_ATTEMPT IMAGE_URI ECR_REPOSITORY SBOM_FILE DEVELOPMENT_URL STAGING_URL PRODUCTION_URL; do
  [[ -n "${!name:-}" ]] || { echo "${name} must be set" >&2; exit 64; }
done

output="${1:-release-manifest.json}"
digest="${IMAGE_URI##*@}"
sbom_sha256="$(sha256sum "$SBOM_FILE" | cut -d' ' -f1)"
released_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${RUN_ID}/attempts/${RUN_ATTEMPT}"
delivery_run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${DELIVERY_RUN_ID}/attempts/${DELIVERY_RUN_ATTEMPT}"

jq -n \
  --arg version "$VERSION" \
  --arg released_at "$released_at" \
  --arg repository "$GITHUB_REPOSITORY" \
  --arg source_sha "$SOURCE_SHA" \
  --arg run_id "$RUN_ID" \
  --arg run_attempt "$RUN_ATTEMPT" \
  --arg run_url "$run_url" \
  --arg artifact_name "deployable-${RUN_ID}-${RUN_ATTEMPT}" \
  --arg delivery_run_id "$DELIVERY_RUN_ID" \
  --arg delivery_run_attempt "$DELIVERY_RUN_ATTEMPT" \
  --arg delivery_run_url "$delivery_run_url" \
  --arg ecr_repository "$ECR_REPOSITORY" \
  --arg image_uri "$IMAGE_URI" \
  --arg digest "$digest" \
  --arg sbom_file "$(basename "$SBOM_FILE")" \
  --arg sbom_sha256 "$sbom_sha256" \
  --arg development_url "$DEVELOPMENT_URL" \
  --arg staging_url "$STAGING_URL" \
  --arg production_url "$PRODUCTION_URL" \
  '{
    schema_version: "1.0",
    release: {
      version: $version,
      tag: ("v" + $version),
      status: "released",
      released_at: $released_at
    },
    source: { repository: $repository, git_sha: $source_sha },
    build: {
      workflow: "CI",
      run_id: ($run_id | tonumber),
      run_attempt: ($run_attempt | tonumber),
      run_url: $run_url,
      artifact_name: $artifact_name
    },
    delivery: {
      workflow: "Delivery",
      run_id: ($delivery_run_id | tonumber),
      run_attempt: ($delivery_run_attempt | tonumber),
      run_url: $delivery_run_url
    },
    artifact: {
      registry: "Amazon ECR",
      repository: $ecr_repository,
      image_uri: $image_uri,
      digest: $digest,
      release_tag: ("release-" + $version)
    },
    sbom: {
      format: "CycloneDX JSON",
      file: $sbom_file,
      sha256: $sbom_sha256
    },
    infrastructure: {
      source_git_sha: $source_sha,
      roots: ["terraform/bootstrap", "terraform/live"],
      state_keys: {
        development: "services/development/terraform.tfstate",
        staging: "services/staging/terraform.tfstate",
        production: "services/production/terraform.tfstate"
      },
      production_plan_artifact: ("production-plan-" + $delivery_run_id + "-" + $delivery_run_attempt)
    },
    promotions: [
      { environment: "development", image_uri: $image_uri, url: $development_url, verified: true },
      { environment: "staging", image_uri: $image_uri, url: $staging_url, verified: true },
      { environment: "production", image_uri: $image_uri, url: $production_url, verified: true }
    ],
    policy: {
      build_once: true,
      same_ecr_repository: true,
      hotfix_path: "standard-trunk-promotion",
      default_recovery: "roll-forward",
      emergency_restore_scope: "application-alias-only",
      flcm_eligible: true,
      flcm_pin: ("release-" + $version)
    }
  }' >"$output"
