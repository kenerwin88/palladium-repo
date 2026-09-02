#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION must be set}"
: "${ECR_REPOSITORY:?ECR_REPOSITORY must be set}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set}"

environment="${1:?usage: apply-plan.sh <environment> <version> <run-id> <run-attempt> <image-uri> <binary-plan>}"
version="${2:?usage: apply-plan.sh <environment> <version> <run-id> <run-attempt> <image-uri> <binary-plan>}"
run_id="${3:?usage: apply-plan.sh <environment> <version> <run-id> <run-attempt> <image-uri> <binary-plan>}"
run_attempt="${4:?usage: apply-plan.sh <environment> <version> <run-id> <run-attempt> <image-uri> <binary-plan>}"
image_uri="${5:?usage: apply-plan.sh <environment> <version> <run-id> <run-attempt> <image-uri> <binary-plan>}"
binary_plan="${6:?usage: apply-plan.sh <environment> <version> <run-id> <run-attempt> <image-uri> <binary-plan>}"

[[ "$environment" == "production" ]] || { echo "exact-plan apply is production-only" >&2; exit 64; }
[[ "$run_id" =~ ^[0-9]+$ && "$run_attempt" =~ ^[0-9]+$ ]] || { echo "invalid run identity" >&2; exit 64; }
[[ "$image_uri" =~ @sha256:([0-9a-f]{64})$ ]] || { echo "image URI must be digest-addressed" >&2; exit 64; }
expected_digest="sha256:${BASH_REMATCH[1]}"
candidate_tag="candidate-${version}-run-${run_id}-a${run_attempt}"

actual_digest="$(aws ecr describe-images --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=${candidate_tag}" --query 'imageDetails[0].imageDigest' --output text)"
[[ "$actual_digest" == "$expected_digest" ]] || { echo "candidate digest changed" >&2; exit 1; }

binary_plan="$(realpath -m "$binary_plan")"
terraform -chdir=terraform/live init -reconfigure -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=services/${environment}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform/live apply -input=false -auto-approve "$binary_plan"

url="$(terraform -chdir=terraform/live output -raw url)"
for attempt in {1..12}; do
  if payload="$(curl --fail --silent --show-error --max-time 10 "${url}healthz")" &&
    jq -e --arg version "$version" '.status == "ok" and .version == $version' <<<"$payload" >/dev/null; then
    break
  fi
  [[ "$attempt" != 12 ]] || { echo "production smoke test failed" >&2; exit 1; }
  sleep 5
done

release_tag="release-${version}"
if release_digest="$(aws ecr describe-images --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=${release_tag}" --query 'imageDetails[0].imageDigest' --output text 2>/dev/null)"; then
  [[ "$release_digest" == "$expected_digest" ]] || { echo "release tag collision" >&2; exit 1; }
else
  manifest="$(aws ecr batch-get-image --repository-name "$ECR_REPOSITORY" \
    --image-ids "imageTag=${candidate_tag}" --query 'images[0].imageManifest' --output text)"
  aws ecr put-image --repository-name "$ECR_REPOSITORY" --image-tag "$release_tag" \
    --image-manifest "$manifest" >/dev/null
fi
aws ecr batch-delete-image --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=${candidate_tag}" >/dev/null

{
  echo "### production deployment"
  echo
  echo "- Applied reviewed plan: \`$(basename "$binary_plan")\`"
  echo "- Version: \`${version}\`"
  echo "- Image: \`${image_uri}\`"
  echo "- Release tag: \`${release_tag}\`"
  echo "- URL: ${url}"
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
echo "url=${url}" >>"${GITHUB_OUTPUT:-/dev/null}"
