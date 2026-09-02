output "aws_region" {
  value = var.aws_region
}

output "deploy_role_arns" {
  value = { for environment, role in aws_iam_role.github_deploy : environment => role.arn }
}

output "ecr_repository" {
  value = aws_ecr_repository.app.name
}

output "plan_role_arn" {
  value = aws_iam_role.github_plan.arn
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}
