#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 6 ]]; then
  echo "usage: deploy.sh <environment> <version> <source-sha> <run-id> <run-attempt> <image-tar> [expires-at]" >&2
  exit 64
fi

: "${AWS_REGION:?AWS_REGION must be set by the GitHub Environment}"
: "${ECR_REPOSITORY:?ECR_REPOSITORY must be set by the GitHub Environment}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set by the GitHub Environment}"

environment="$1"
version="$2"
source_sha="$3"
run_id="$4"
run_attempt="$5"
image_tar="$6"
expires_at="${7:-}"

case "$environment" in
  development|staging|production|pr-[0-9]*) ;;
  *) echo "invalid environment: $environment" >&2; exit 64 ;;
esac
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo "invalid source SHA" >&2; exit 64; }
[[ "$run_id" =~ ^[0-9]+$ ]] || { echo "invalid workflow run ID" >&2; exit 64; }
[[ "$run_attempt" =~ ^[0-9]+$ ]] || { echo "invalid workflow run attempt" >&2; exit 64; }
[[ -f "$image_tar" ]] || { echo "image archive not found: $image_tar" >&2; exit 66; }

account_id="$(aws sts get-caller-identity --query Account --output text)"
registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
source_image="palladium-build:${source_sha}"
repository_uri="${registry}/${ECR_REPOSITORY}"
if [[ "$environment" == pr-* ]]; then
  candidate_tag="preview-${environment}-run-${run_id}-a${run_attempt}"
else
  candidate_tag="candidate-${version}-run-${run_id}-a${run_attempt}"
fi

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$registry"
docker load --input "$image_tar"
docker image inspect "$source_image" >/dev/null

if ! digest="$(aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=${candidate_tag}" \
  --query 'imageDetails[0].imageDigest' --output text 2>/dev/null)"; then
  docker tag "$source_image" "${repository_uri}:${candidate_tag}"
  docker push "${repository_uri}:${candidate_tag}"
  digest="$(aws ecr describe-images \
    --repository-name "$ECR_REPOSITORY" \
    --image-ids "imageTag=${candidate_tag}" \
    --query 'imageDetails[0].imageDigest' --output text)"
fi

image_uri="${repository_uri}@${digest}"
state_key="services/${environment}/terraform.tfstate"
tfvars_file="terraform/live/tfvars/${environment}.tfvars"
[[ "$environment" == pr-* ]] && tfvars_file="terraform/live/tfvars/preview.tfvars"

terraform -chdir=terraform/live init -reconfigure -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${state_key}" \
  -backend-config="region=${AWS_REGION}"

terraform -chdir=terraform/live plan -input=false -out=deploy.tfplan \
  -var-file="${tfvars_file#terraform/live/}" \
  -var="aws_region=${AWS_REGION}" \
  -var="environment=${environment}" \
  -var="expires_at=${expires_at}" \
  -var="image_uri=${image_uri}" \
  -var="project=${ECR_REPOSITORY}" \
  -var="repository=${GITHUB_REPOSITORY}" \
  -var="application_version=${version}"
terraform -chdir=terraform/live apply -input=false -auto-approve deploy.tfplan

url="$(terraform -chdir=terraform/live output -raw url)"
for attempt in {1..12}; do
  if payload="$(curl --fail --silent --show-error --max-time 10 "${url}healthz")"; then
    actual_version="$(jq -r '.version' <<<"$payload")"
    [[ "$actual_version" == "$version" ]] || {
      echo "smoke test reached version ${actual_version}, expected ${version}" >&2
      exit 1
    }
    break
  fi
  if [[ "$attempt" == 12 ]]; then
    echo "smoke test failed after 12 attempts: ${url}healthz" >&2
    exit 1
  fi
  sleep 5
done

if [[ "$environment" == "production" ]]; then
  release_tag="release-${version}"
  if release_digest="$(aws ecr describe-images --repository-name "$ECR_REPOSITORY" \
    --image-ids "imageTag=${release_tag}" --query 'imageDetails[0].imageDigest' \
    --output text 2>/dev/null)"; then
    [[ "$release_digest" == "$digest" ]] || {
      echo "release tag ${release_tag} already identifies a different digest" >&2
      exit 1
    }
  else
    manifest="$(aws ecr batch-get-image --repository-name "$ECR_REPOSITORY" \
      --image-ids "imageTag=${candidate_tag}" --query 'images[0].imageManifest' --output text)"
    aws ecr put-image --repository-name "$ECR_REPOSITORY" \
      --image-tag "$release_tag" --image-manifest "$manifest" >/dev/null
  fi
  aws ecr batch-delete-image --repository-name "$ECR_REPOSITORY" \
    --image-ids "imageTag=${candidate_tag}" >/dev/null
elif [[ "$environment" == pr-* ]]; then
  aws ecr batch-delete-image --repository-name "$ECR_REPOSITORY" \
    --image-ids "imageTag=${candidate_tag}" >/dev/null
fi

{
  echo "### ${environment} deployment"
  echo
  echo "- Version: \`${version}\`"
  echo "- Image: \`${image_uri}\`"
  echo "- Workflow run: \`${run_id}\`, attempt \`${run_attempt}\`"
  echo "- URL: ${url}"
} >>"${GITHUB_STEP_SUMMARY:-/dev/null}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "url=${url}" >>"$GITHUB_OUTPUT"
  echo "image_uri=${image_uri}" >>"$GITHUB_OUTPUT"
fi
