# Lab M4.05 - Create Your First Terraform Module

> Instructions copied from the Ironhack Student Portal
> (Module 4, Week 4 - Infrastructure as Code with Terraform, Unit 4.2.4 - "LAB | Build Your First Module").

**Repository:** https://github.com/cloud-engineering-bootcamp/ce-lab-terraform-module

**Activity Type:** Individual
**Estimated Time:** 60-90 minutes
**Submission:** GitHub Repository

**Skills you will learn**

- Infrastructure as Code: Modules
- Development Workflow: Code Reusability

## Learning Objectives

- Create a reusable Terraform module
- Define module inputs (variables) and outputs
- Structure module files properly
- Use module in multiple environments
- Understand module composition patterns
- Version and document modules

## Prerequisites

- Completed Labs M4.01-M4.04
- Understanding of Terraform resources and variables
- Git knowledge for versioning

## Introduction

You've been copying VPC configurations for dev, staging, and prod. Time to DRY (Don't Repeat
Yourself)! Create a reusable VPC module that works across all environments with different
configurations.

## Scenario

Your company needs standard VPC configurations:

- **Dev:** Single NAT Gateway (cost savings)
- **Staging:** Multi-AZ NAT Gateways
- **Prod:** Multi-AZ with additional security

Instead of maintaining three separate configurations, create one module with parameters.

## Your Task

**What you'll create:**

- VPC module with public/private subnets
- Configurable NAT Gateway (single/multi-AZ)
- Module used in dev and prod environments
- Complete module documentation
- Module versioned in Git

**Success criteria:**

- Module creates VPC with subnets across 2+ AZs
- Internet Gateway and NAT Gateway configured
- Module has well-defined inputs and outputs
- Successfully deployed to dev and prod
- README documents module usage

**Time limit:** 60-90 minutes

---

## Step-by-Step Instructions

### Step 1: Create Module Structure

```bash
mkdir -p ~/ce-labs/m4-05-terraform-module
cd ~/ce-labs/m4-05-terraform-module

# Create module directory
mkdir -p modules/vpc

# Create module files
touch modules/vpc/main.tf
touch modules/vpc/variables.tf
touch modules/vpc/outputs.tf
touch modules/vpc/README.md
```

### Step 2: Define Module Variables

Create `modules/vpc/variables.tf`:

```hcl
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost savings)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
```

### Step 3: Create Module Resources

Create `modules/vpc/main.tf`:

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-vpc"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-public-${count.index + 1}"
      Environment = var.environment
      Tier        = "Public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-private-${count.index + 1}"
      Environment = var.environment
      Tier        = "Private"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    }
  )
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 1
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    }
  )
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
```

### Step 4: Define Module Outputs

Create `modules/vpc/outputs.tf`:

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = aws_route_table.private[*].id
}
```

### Step 5: Document the Module

Create `modules/vpc/README.md` documenting features, usage, inputs and outputs:

- Multi-AZ deployment (2+ availability zones)
- Public and private subnets
- Internet Gateway for public subnet internet access
- NAT Gateway for private subnet outbound access
- Configurable single or multi-AZ NAT Gateway
- Comprehensive tagging strategy

Usage example:

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name         = "myproject"
  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost savings for dev

  tags = {
    Owner = "DevTeam"
  }
}
```

Inputs table:

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |
| environment | Environment (dev/staging/prod) | `string` | n/a | yes |
| vpc_cidr | VPC CIDR block | `string` | `"10.0.0.0/16"` | no |
| availability_zones | List of AZs | `list(string)` | n/a | yes |
| public_subnet_cidrs | Public subnet CIDRs | `list(string)` | n/a | yes |
| private_subnet_cidrs | Private subnet CIDRs | `list(string)` | n/a | yes |
| enable_nat_gateway | Enable NAT Gateway | `bool` | `true` | no |
| single_nat_gateway | Use single NAT | `bool` | `false` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

Outputs table:

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| internet_gateway_id | Internet Gateway ID |
| nat_gateway_ids | NAT Gateway IDs |

### Step 6: Use Module in Dev Environment

Create `main.tf` (root):

```hcl
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
}

module "vpc_dev" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost savings for dev

  tags = {
    Owner = "DevTeam"
  }
}

# Use module outputs
output "dev_vpc_id" {
  value = module.vpc_dev.vpc_id
}

output "dev_public_subnets" {
  value = module.vpc_dev.public_subnet_ids
}
```

Create `variables.tf`:

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "myproject"
}
```

### Step 7: Deploy Dev Environment

```bash
# Initialize (downloads module)
terraform init

# Format code
terraform fmt -recursive

# Validate
terraform validate

# Plan
terraform plan

# Apply
terraform apply -auto-approve
```

**Expected outcome:** VPC with 2 public subnets, 2 private subnets, IGW, 1 NAT Gateway.

### Step 8: Add Prod Environment

Add to `main.tf`:

```hcl
module "vpc_prod" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = "prod"
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false # HA for prod

  tags = {
    Owner      = "PlatformTeam"
    Compliance = "SOC2"
  }
}

output "prod_vpc_id" {
  value = module.vpc_prod.vpc_id
}
```

Deploy:

```bash
terraform apply -auto-approve
```

**Expected outcome:** Second VPC with 2 NAT Gateways (HA).

### Step 9: Version the Module

```bash
# Create git repository
git init
git add .
git commit -m "Initial VPC module - v1.0.0"

# Tag version
git tag v1.0.0

# Push to GitHub
gh repo create ce-lab-terraform-module --public
git push -u origin main
git push --tags
```

### Step 10: Use Module from Git

Create new project to use module from Git:

```hcl
module "vpc" {
  source = "github.com/YOUR_USERNAME/ce-lab-terraform-module//modules/vpc?ref=v1.0.0"

  project_name         = "external-project"
  environment          = "test"
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24"]
  enable_nat_gateway   = false
  single_nat_gateway   = false
}
```

---

## Grading Rubric (100 points)

| Criteria | Points |
|----------|-------:|
| Module structure correct | 15 |
| Variables well-defined | 20 |
| Resources implemented | 25 |
| Outputs defined | 10 |
| Used in multiple environments | 15 |
| Documentation complete | 10 |
| Module versioned | 5 |

## Key Takeaways

- Modules enable code reuse
- Variables make modules flexible
- Outputs expose information
- Documentation is essential
- Versioning ensures stability
- DRY principle saves time and reduces errors

**Next Lab:** M4.06 - Use Community Modules from Terraform Registry
