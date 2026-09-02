variable "aws_region" {
  description = "AWS region used by this environment account."
  type        = string
  default     = "us-east-2"
}

variable "github_environments" {
  description = "GitHub Environments allowed to assume the deployment role."
  type        = set(string)
}

variable "project" {
  description = "Short project identifier."
  type        = string
  default     = "palladium"
}

variable "repository" {
  description = "GitHub repository in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository))
    error_message = "repository must use owner/name format."
  }
}

