variable "project" {
  description = "Name of project"
  type        = string
}
variable "env" {
  description = "Name of project environment"
  type        = string
}
variable "region" {
  description = "Region of environment"
  type        = string
}
variable "container_image_tag" {
  description = "Docker container image tag for the screenshot processing application"
  type        = string
  default     = "latest"
}

variable "alert_email" {
  description = "Email address for receiving alerts and budget notifications"
  type        = string
  default     = ""
}

# Budget configuration variables
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 20
}

variable "daily_budget_limit" {
  description = "Daily budget limit in USD"
  type        = number
  default     = 5
}

variable "ecs_budget_limit" {
  description = "ECS-specific monthly budget limit in USD"
  type        = number
  default     = 10
}
