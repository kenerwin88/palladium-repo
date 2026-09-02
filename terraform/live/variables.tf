variable "alarm_topic_arn" {
  type      = string
  default   = null
  nullable  = true
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "environment" {
  type = string
}

variable "expires_at" {
  type    = string
  default = ""
}

variable "image_uri" {
  type = string
}

variable "log_retention_days" {
  type = number
}

variable "memory_size" {
  type = number
}

variable "project" {
  type = string
}

variable "repository" {
  description = "GitHub owner/repository."
  type        = string
}

variable "application_version" {
  type = string
}
