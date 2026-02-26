variable "region" {
  type        = string
  default     = "asia-northeast1"
  description = "Deployment region"
}

locals {
  service_name = "sample-app"
}

output "service_name" {
  value       = local.service_name
  description = "Service name"
}
