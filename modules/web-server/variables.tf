variable "name" {
  description = "Base name for all resources created by this module (e.g. \"ironhack-web\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "Name must be 3-32 lowercase letters, numbers or hyphens, and cannot start or end with a hyphen."
  }
}

variable "environment" {
  description = "Environment this deployment belongs to."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "instance_count" {
  description = "Number of web server instances to create."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the web servers."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must look like a valid EC2 type, e.g. t3.micro."
  }
}

variable "ami_id" {
  description = "AMI to launch. Defaults to the latest Amazon Linux 2023 x86_64 AMI when null."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC to deploy into. Defaults to the account's default VPC when null."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnets to spread instances across. Defaults to all subnets in the VPC when empty."
  type        = list(string)
  default     = []
}

variable "http_port" {
  description = "TCP port the web server listens on."
  type        = number
  default     = 80

  validation {
    condition     = var.http_port > 0 && var.http_port <= 65535
    error_message = "HTTP port must be between 1 and 65535."
  }
}

variable "allowed_http_cidr_blocks" {
  description = "CIDR blocks allowed to reach the HTTP port."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_http_cidr_blocks) > 0
    error_message = "At least one HTTP CIDR block must be provided."
  }
}

variable "enable_ssh" {
  description = "Whether to open SSH (port 22) on the security group."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH. Only used when enable_ssh = true."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_cidr_blocks, "0.0.0.0/0")
    error_message = "SSH must not be opened to 0.0.0.0/0. Restrict it to a known CIDR."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair to attach. Null means no key pair."
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Whether to assign a public IP address to each instance."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the encrypted gp3 root volume, in GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GiB."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable EC2 detailed (1-minute) CloudWatch monitoring."
  type        = bool
  default     = false
}

variable "server_message" {
  description = "Headline rendered on the default web page."
  type        = string
  default     = "Hello from Terraform!"
}

variable "tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}
