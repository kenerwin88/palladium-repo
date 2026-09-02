#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION must be set}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set}"

environment="${1:?usage: apply-environment-plan.sh <environment> <version> <binary-plan>}"
version="${2:?usage: apply-environment-plan.sh <environment> <version> <binary-plan>}"
binary_plan="${3:?usage: apply-environment-plan.sh <environment> <version> <binary-plan>}"
[[ "$environment" == "flcm" ]] || { echo "this entry point is restricted to FLCM" >&2; exit 64; }
binary_plan="$(realpath -m "$binary_plan")"

terraform -chdir=terraform/live init -reconfigure -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=services/${environment}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform/live apply -input=false -auto-approve "$binary_plan"

url="$(terraform -chdir=terraform/live output -raw url)"
curl --fail --silent --show-error --retry 8 --retry-all-errors "${url}healthz" | jq -e \
  --arg version "$version" '.status == "ok" and .version == $version'
{
  echo "### FLCM pinned"
  echo
  echo "- Version: \`${version}\`"
  echo "- Applied reviewed plan: \`$(basename "$binary_plan")\`"
  echo "- URL: ${url}"
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
