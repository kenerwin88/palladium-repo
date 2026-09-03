variable "environment" {
  description = "Long-lived environment name or pr-N preview identifier."
  type        = string

  validation {
    condition     = can(regex("^(development|staging|production|legacy|pr-[0-9]+)$", var.environment))
    error_message = "Environment must be development, staging, production, legacy, or pr-N."
  }
}

variable "image_uri" {
  description = "Immutable, same-account ECR image URI addressed by sha256 digest."
  type        = string

  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image_uri))
    error_message = "image_uri must be immutable and end in @sha256:<64 hex characters>."
  }
}

variable "memory_size" {
  description = "Lambda memory in MiB. CPU allocation scales with this value."
  type        = number
  default     = 512
}

variable "project" {
  description = "Short project identifier used in resource names."
  type        = string
}

variable "application_version" {
  description = "Calendar version embedded in runtime metadata."
  type        = string
}

variable "alarm_topic_arn" {
  description = "Optional SNS topic for production alarms."
  type        = string
  default     = null
}

variable "expires_at" {
  description = "RFC3339 preview expiry timestamp, empty for long-lived environments."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 30
}
