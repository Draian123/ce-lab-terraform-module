# VPC Terraform Module

Creates a multi-AZ VPC with public and private subnets, Internet Gateway, and NAT Gateway.

## Features

- Multi-AZ deployment (2+ availability zones)
- Public and private subnets
- Internet Gateway for public subnet internet access
- NAT Gateway for private subnet outbound access
- Configurable single or multi-AZ NAT Gateway
- Comprehensive tagging strategy

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws provider | ~> 5.0 |

## Usage

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

Consuming the module straight from Git at a pinned version:

```hcl
module "vpc" {
  source = "github.com/Draian123/ce-lab-terraform-module//modules/vpc?ref=v1.0.0"
  # ...same inputs as above
}
```

## NAT Gateway modes

The two NAT flags combine into three deployment shapes:

| `enable_nat_gateway` | `single_nat_gateway` | NAT Gateways | Private route tables | Typical use |
|:---:|:---:|:---:|:---:|---|
| `true` | `true` | 1 | 1 shared | **dev** — cheapest, no AZ redundancy |
| `true` | `false` | one per public subnet | one per private subnet | **staging / prod** — AZ-independent egress |
| `false` | *(ignored)* | 0 | 1 (no default route) | fully isolated / test |

With multi-AZ NAT each private subnet routes through the NAT Gateway in its own AZ, so an AZ
outage cannot take out egress for the other AZ and no cross-AZ data transfer is billed.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name used as a name prefix | `string` | n/a | yes |
| environment | Environment (dev/staging/prod) | `string` | n/a | yes |
| vpc_cidr | VPC CIDR block | `string` | `"10.0.0.0/16"` | no |
| availability_zones | List of AZs (2+) | `list(string)` | n/a | yes |
| public_subnet_cidrs | Public subnet CIDRs (2+) | `list(string)` | n/a | yes |
| private_subnet_cidrs | Private subnet CIDRs (2+) | `list(string)` | n/a | yes |
| enable_nat_gateway | Enable NAT Gateway | `bool` | `true` | no |
| single_nat_gateway | Use single NAT Gateway | `bool` | `false` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

### Validation rules

- `project_name` — 3-32 chars, lowercase letters, digits, hyphens
- `environment` — must be one of `dev`, `staging`, `prod`
- `vpc_cidr` — must be a valid IPv4 CIDR block
- `availability_zones` — at least 2 entries
- `public_subnet_cidrs` / `private_subnet_cidrs` — at least 2 entries, each a valid IPv4 CIDR
- precondition on the VPC — `availability_zones` must be at least as long as the longest subnet list

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| vpc_arn | VPC ARN |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| public_subnet_cidrs | Public subnet CIDR blocks |
| private_subnet_cidrs | Private subnet CIDR blocks |
| availability_zones | AZs the subnets landed in |
| internet_gateway_id | Internet Gateway ID |
| nat_gateway_ids | NAT Gateway IDs (empty when NAT disabled) |
| nat_public_ips | Elastic IPs of the NAT Gateways |
| public_route_table_id | Public route table ID |
| private_route_table_ids | Private route table IDs |
| name_prefix | `<project_name>-<environment>` prefix |
| summary | Object summarising the VPC, subnet counts and NAT mode |

## Resources created

| Resource | Count |
|----------|-------|
| `aws_vpc` | 1 |
| `aws_subnet` (public) | `length(public_subnet_cidrs)` |
| `aws_subnet` (private) | `length(private_subnet_cidrs)` |
| `aws_internet_gateway` | 1 |
| `aws_eip` | = NAT Gateway count |
| `aws_nat_gateway` | 0 / 1 / one per public subnet |
| `aws_route_table` (public) | 1 |
| `aws_route_table` (private) | 1 or one per private subnet |
| `aws_route_table_association` | one per subnet |

## Tagging

Every resource gets `var.tags` merged with a `Name` built from `name_prefix`, plus `Environment`.
The VPC also carries `ManagedBy = "Terraform"`, and subnets/route tables carry
`Tier = "Public" | "Private"`. Module tags never overwrite provider `default_tags` keys unless the
same key is passed in `var.tags`.

## Cost note

NAT Gateways are billed hourly per gateway plus data processing, and each carries an Elastic IP.
`single_nat_gateway = true` is the right default for dev; `false` doubles the hourly NAT cost in a
two-AZ layout in exchange for AZ-independent egress. Everything else in this module (VPC, subnets,
IGW, route tables) is free.

## Examples

See the [`examples/`](../../examples) directory for usage examples, including consuming this module
from Git at a pinned tag.
