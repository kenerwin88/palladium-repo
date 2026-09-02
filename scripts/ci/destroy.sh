#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION must be set}"
: "${ECR_REPOSITORY:?ECR_REPOSITORY must be set}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set}"

environment="${1:?usage: destroy.sh pr-N}"
[[ "$environment" =~ ^pr-[0-9]+$ ]] || { echo "refusing to destroy non-preview environment" >&2; exit 64; }

account_id="$(aws sts get-caller-identity --query Account --output text)"
placeholder_image="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}@sha256:$(printf '0%.0s' {1..64})"

terraform -chdir=terraform/live init -reconfigure -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=services/${environment}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform/live destroy -auto-approve -input=false \
  -var-file=tfvars/preview.tfvars \
  -var="aws_region=${AWS_REGION}" \
  -var="environment=${environment}" \
  -var="image_uri=${placeholder_image}" \
  -var="project=${ECR_REPOSITORY}" \
  -var="repository=${GITHUB_REPOSITORY}" \
  -var="application_version=destroyed"
