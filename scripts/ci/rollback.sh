#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION must be set}"
: "${ECR_REPOSITORY:?ECR_REPOSITORY must be set}"

environment="${1:?usage: rollback.sh <environment> <calendar-version>}"
version="${2:?usage: rollback.sh <environment> <calendar-version>}"
[[ "$environment" =~ ^(development|staging|production)$ ]] || { echo "invalid environment" >&2; exit 64; }
[[ "$version" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$ ]] || { echo "invalid calendar version" >&2; exit 64; }

account_id="$(aws sts get-caller-identity --query Account --output text)"
digest="$(aws ecr describe-images --repository-name "$ECR_REPOSITORY" \
  --image-ids "imageTag=release-${version}" --query 'imageDetails[0].imageDigest' --output text)"
image_uri="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}@${digest}"
function_name="${ECR_REPOSITORY}-${environment}"

current_function_version="$(aws lambda get-alias --function-name "$function_name" \
  --name live --query FunctionVersion --output text)"
target_function_version=""
while IFS= read -r function_version; do
  configured_version="$(aws lambda get-function-configuration \
    --function-name "$function_name" --qualifier "$function_version" \
    --query 'Environment.Variables.APP_VERSION' --output text)"
  [[ "$configured_version" == "$version" ]] || continue
  deployed_image="$(aws lambda get-function --function-name "$function_name" \
    --qualifier "$function_version" --query 'Code.ImageUri' --output text)"
  [[ "$deployed_image" == "$image_uri" ]] || {
    echo "Lambda version ${function_version} says ${version} but uses ${deployed_image}, not ${image_uri}" >&2
    exit 1
  }
  target_function_version="$function_version"
  break
done < <(aws lambda list-versions-by-function --function-name "$function_name" \
  --query 'Versions[].Version' --output text | tr '\t' '\n' | sed '/^\$LATEST$/d' | sort -rn)

[[ -n "$target_function_version" ]] || {
  echo "no retained Lambda version for release ${version}; roll forward instead" >&2
  exit 1
}

aws lambda update-alias --function-name "$function_name" --name live \
  --function-version "$target_function_version" \
  --description "Emergency app-only restore to ${version}" >/dev/null

url="$(aws lambda get-function-url-config --function-name "$function_name" \
  --qualifier live --query FunctionUrl --output text)"
curl --fail --silent --show-error --retry 8 --retry-all-errors "${url}healthz" | jq -e \
  --arg version "$version" '.status == "ok" and .version == $version'
{
  echo "### Exceptional application-only restore"
  echo
  echo "- Environment: \`${environment}\`"
  echo "- Release: \`${version}\`"
  echo "- ECR digest: \`${image_uri}\`"
  echo "- Lambda alias: \`${current_function_version}\` -> \`${target_function_version}\`"
  echo "- URL: ${url}"
  echo
  echo "> Terraform was intentionally not run. The next normal roll-forward reconciles the alias."
} >>"$GITHUB_STEP_SUMMARY"
