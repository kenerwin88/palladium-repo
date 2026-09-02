data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  state_bucket_name   = "${var.project}-${local.account_id}-${var.aws_region}-tfstate"
  deploy_environments = { for environment in var.github_environments : environment => environment }
  github_plan_subject = "repo:${var.repository}:environment:plan"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged preview and discarded images after fourteen days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove abandoned release candidates after thirty days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["candidate-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Remove stale preview tags if cleanup did not run"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["preview-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 14
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_deploy" {
  for_each = local.deploy_environments
  name     = "${var.project}-github-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.repository}:environment:${each.key}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_deploy" {
  for_each = local.deploy_environments
  name     = "deployment-control-plane"
  role     = aws_iam_role.github_deploy[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
        Resource = each.key == "preview" ? "${aws_s3_bucket.state.arn}/services/pr-*" : "${aws_s3_bucket.state.arn}/services/${each.key}/terraform.tfstate*"
      },
      {
        Sid      = "ContainerRegistryLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ContainerRegistry"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:BatchDeleteImage", "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload", "ecr:DescribeImages", "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload", "ecr:ListImages", "ecr:PutImage", "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "LambdaServices"
        Effect = "Allow"
        Action = [
          "lambda:AddPermission", "lambda:CreateAlias", "lambda:CreateFunction",
          "lambda:CreateFunctionUrlConfig", "lambda:DeleteAlias", "lambda:DeleteFunction",
          "lambda:DeleteFunctionUrlConfig", "lambda:GetAlias", "lambda:GetFunction",
          "lambda:GetFunctionCodeSigningConfig", "lambda:GetFunctionUrlConfig", "lambda:GetPolicy",
          "lambda:ListTags", "lambda:ListVersionsByFunction", "lambda:PublishVersion",
          "lambda:RemovePermission", "lambda:TagResource", "lambda:UntagResource",
          "lambda:UpdateAlias", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
          "lambda:UpdateFunctionUrlConfig"
        ]
        Resource = each.key == "preview" ? "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.project}-pr-*" : "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.project}-${each.key}*"
      },
      {
        Sid      = "LambdaInventory"
        Effect   = "Allow"
        Action   = ["lambda:ListFunctions"]
        Resource = "*"
      },
      {
        Sid    = "RuntimeRoles"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy", "iam:CreateRole", "iam:DeleteRole", "iam:DetachRolePolicy",
          "iam:GetRole", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:ListRolePolicies", "iam:PassRole", "iam:TagRole", "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = each.key == "preview" ? "arn:aws:iam::${local.account_id}:role/${var.project}-pr-*-runtime" : "arn:aws:iam::${local.account_id}:role/${var.project}-${each.key}-runtime"
      },
      {
        Sid    = "Observability"
        Effect = "Allow"
        Action = [
          "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource",
          "cloudwatch:PutMetricAlarm", "cloudwatch:TagResource", "cloudwatch:UntagResource",
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:ListTagsForResource", "logs:PutRetentionPolicy", "logs:TagResource", "logs:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "github_plan" {
  name = "${var.project}-github-plan"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.github_plan_subject
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_plan" {
  name = "read-only-terraform-plan"
  role = aws_iam_role.github_plan.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid      = "TerraformStateObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.state.arn}/*"
      },
      {
        Sid    = "ReadApplicationResources"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource",
          "ecr:DescribeImages", "ecr:ListImages",
          "iam:GetRole", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:ListRolePolicies", "iam:GetRolePolicy",
          "lambda:GetAlias", "lambda:GetFunction", "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetFunctionUrlConfig", "lambda:GetPolicy", "lambda:ListTags",
          "lambda:ListVersionsByFunction", "logs:DescribeLogGroups", "logs:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })
}
