output "function_arn" {
  description = "Deployed Lambda function ARN."
  value       = aws_lambda_function.app.arn
}

output "url" {
  description = "Stable environment URL."
  value       = aws_lambda_function_url.app.function_url
}

output "version" {
  description = "Published Lambda version."
  value       = aws_lambda_function.app.version
}

output "image_uri" {
  description = "Immutable container digest currently deployed."
  value       = aws_lambda_function.app.image_uri
}

output "runtime_version" {
  description = "Calendar version exposed by the application."
  value       = var.application_version
}
