#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION must be set}"
: "${ECR_REPOSITORY:?ECR_REPOSITORY must be set}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set}"

environment="${1:?usage: plan.sh <environment> <image-uri> <version> <binary-plan> <text-plan> [expires-at]}"
image_uri="${2:?usage: plan.sh <environment> <image-uri> <version> <binary-plan> <text-plan> [expires-at]}"
version="${3:?usage: plan.sh <environment> <image-uri> <version> <binary-plan> <text-plan> [expires-at]}"
binary_plan="${4:?usage: plan.sh <environment> <image-uri> <version> <binary-plan> <text-plan> [expires-at]}"
text_plan="${5:?usage: plan.sh <environment> <image-uri> <version> <binary-plan> <text-plan> [expires-at]}"
expires_at="${6:-}"

[[ "$environment" =~ ^(development|staging|production|flcm)$ ]] || { echo "invalid environment" >&2; exit 64; }
[[ "$image_uri" =~ @sha256:[0-9a-f]{64}$ ]] || { echo "image URI must be digest-addressed" >&2; exit 64; }
[[ "$version" =~ ^([0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+|pr-[0-9]+-[0-9a-f]{7})$ ]] || { echo "invalid application version" >&2; exit 64; }

binary_plan="$(realpath -m "$binary_plan")"
text_plan="$(realpath -m "$text_plan")"
mkdir -p "$(dirname "$binary_plan")" "$(dirname "$text_plan")"

terraform -chdir=terraform/live init -reconfigure -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=services/${environment}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"

terraform -chdir=terraform/live plan -input=false -lock=false -detailed-exitcode -out="$binary_plan" \
  -var-file="tfvars/${environment}.tfvars" \
  -var="aws_region=${AWS_REGION}" \
  -var="environment=${environment}" \
  -var="expires_at=${expires_at}" \
  -var="image_uri=${image_uri}" \
  -var="project=${ECR_REPOSITORY}" \
  -var="repository=${GITHUB_REPOSITORY}" \
  -var="application_version=${version}" || status=$?

status="${status:-0}"
[[ "$status" == 0 || "$status" == 2 ]] || exit "$status"
terraform -chdir=terraform/live show -no-color "$binary_plan" >"$text_plan"
echo "changes=$([[ "$status" == 2 ]] && echo true || echo false)" >>"${GITHUB_OUTPUT:-/dev/null}"
