module "web_service" {
  source = "../modules/web-service"

  application_version = var.application_version
  alarm_topic_arn     = var.alarm_topic_arn
  environment         = var.environment
  expires_at          = var.expires_at
  image_uri           = var.image_uri
  log_retention_days  = var.log_retention_days
  memory_size         = var.memory_size
  project             = var.project
}
