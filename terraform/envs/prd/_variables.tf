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
