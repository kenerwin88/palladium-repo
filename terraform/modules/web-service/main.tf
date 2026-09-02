locals {
  function_name = substr("${var.project}-${var.environment}", 0, 64)
  is_production = var.environment == "production"
  alarm_actions = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  common_tags = {
    Application = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    ExpiresAt   = var.expires_at
  }
}

resource "aws_iam_role" "runtime" {
  name = "${local.function_name}-runtime"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.runtime.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray_write" {
  role       = aws_iam_role.runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "app" {
  function_name = local.function_name
  description   = "${var.project} ${var.environment} (${var.application_version})"
  role          = aws_iam_role.runtime.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["x86_64"]
  memory_size   = var.memory_size
  timeout       = 15
  publish       = true

  environment {
    variables = {
      APP_ENV     = var.environment
      APP_VERSION = var.application_version
      LOG_LEVEL   = local.is_production ? "INFO" : "DEBUG"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.app,
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy_attachment.xray_write,
  ]
  tags = local.common_tags
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Stable URL for ${var.application_version}"
  function_name    = aws_lambda_function.app.function_name
  function_version = aws_lambda_function.app.version
}

resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app.function_name
  qualifier          = aws_lambda_alias.live.name
  authorization_type = "NONE"
  invoke_mode        = "BUFFERED"
}

resource "aws_lambda_permission" "public_url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.app.function_name
  principal              = "*"
  qualifier              = aws_lambda_alias.live.name
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "public_invoke" {
  statement_id             = "AllowPublicInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.app.function_name
  principal                = "*"
  qualifier                = aws_lambda_alias.live.name
  invoked_via_function_url = true
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.function_name}-errors"
  alarm_description   = "${local.function_name} returned errors in two consecutive periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "duration" {
  alarm_name          = "${local.function_name}-duration"
  alarm_description   = "${local.function_name} p95 duration exceeded ten seconds."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 10000
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }
  tags = local.common_tags
}
