# ---------------------------------------------------------------------------
# Step 10 — consume the module from Git at a pinned version.
#
# This is a standalone configuration: it has its own state and does not read
# anything from the root config one directory up. Run it with:
#
#   cd examples/vpc-from-git
#   terraform init      # clones the module from GitHub at tag v1.0.0
#   terraform plan
#
# NAT is disabled here so the example costs nothing to apply.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "github.com/Draian123/ce-lab-terraform-module//modules/vpc?ref=v1.0.0"

  project_name         = "external-project"
  environment          = "dev"
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24"]
  enable_nat_gateway   = false
  single_nat_gateway   = false

  tags = {
    Owner = "ExternalTeam"
  }
}

output "vpc_id" {
  description = "ID of the VPC created from the Git-sourced module."
  value       = module.vpc.vpc_id
}

output "summary" {
  description = "Summary reported by the Git-sourced module."
  value       = module.vpc.summary
}
