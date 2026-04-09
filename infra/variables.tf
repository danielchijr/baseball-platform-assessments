variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  default     = "baseball-data-platform"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  default     = "dev"
}

variable "budget_limit" {
  description = "Monthly budget limit in USD"
  default     = "100"
}

variable "notification_email" {
  description = "Email for budget alerts"
  default     = "admin@example.com"
}

variable "common_tags" {
  description = "Mandatory resource tags"
  type        = map(string)
  default = {
    App        = "baseball-analytics"
    Env        = "dev"
    Owner      = "platform-team"
    CostCenter = "1234"
  }
}
