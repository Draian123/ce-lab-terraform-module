variable "aws_region" {
  description = "AWS region used for every environment in this configuration."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name shared by all environments; becomes the module's name prefix."
  type        = string
  default     = "ironhack-vpc"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "Project name must be lowercase letters, numbers or hyphens."
  }
}

variable "availability_zones" {
  description = "Availability zones used by both environments. Must belong to var.aws_region."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}
