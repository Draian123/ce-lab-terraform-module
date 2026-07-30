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
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Lab       = "M4.05-create-your-first-terraform-module"
      ManagedBy = "Terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Development environment
# Single NAT Gateway shared by both private subnets — cost savings, accepts
# that an AZ outage takes private egress with it.
# ---------------------------------------------------------------------------
module "vpc_dev" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost savings for dev

  tags = {
    Owner = "DevTeam"
  }
}

# ---------------------------------------------------------------------------
# Production environment
# Same module, different inputs: a separate CIDR range and one NAT Gateway per
# AZ so egress survives the loss of a single availability zone.
# ---------------------------------------------------------------------------
module "vpc_prod" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = "prod"
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false # HA for prod

  tags = {
    Owner      = "PlatformTeam"
    Compliance = "SOC2"
  }
}
