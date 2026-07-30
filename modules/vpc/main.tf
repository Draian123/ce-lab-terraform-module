terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Derived counts
#
# nat_gateway_count       0 when NAT is disabled, 1 when shared, otherwise one
#                         NAT Gateway per public subnet (one per AZ).
# private_route_table_...  one shared table when NAT is disabled or shared,
#                         otherwise one table per private subnet so each AZ
#                         routes through the NAT Gateway in its own AZ.
# ---------------------------------------------------------------------------
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  private_route_table_count = var.enable_nat_gateway && !var.single_nat_gateway ? length(var.private_subnet_cidrs) : 1

  # Index of the private route table a given private subnet attaches to.
  # Collapses to 0 whenever there is only one shared table.
  shared_private_route_table = local.private_route_table_count == 1
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-vpc"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  lifecycle {
    precondition {
      condition     = length(var.availability_zones) >= max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs))
      error_message = "availability_zones must have at least as many entries as the longest subnet CIDR list."
    }
  }
}

# ---------------------------------------------------------------------------
# Subnets — one public and one private subnet per supplied CIDR, spread across
# the availability zones in the same order.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-public-${count.index + 1}"
      Environment = var.environment
      Tier        = "Public"
    }
  )
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-private-${count.index + 1}"
      Environment = var.environment
      Tier        = "Private"
    }
  )
}

# ---------------------------------------------------------------------------
# Internet Gateway — inbound/outbound internet for the public subnets.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-igw"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------
# NAT Gateways — outbound-only internet for the private subnets. Each NAT
# Gateway lives in a public subnet and needs its own Elastic IP.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-nat-eip-${count.index + 1}"
      Environment = var.environment
    }
  )
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-nat-${count.index + 1}"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------
# Public routing — one table, default route via the Internet Gateway.
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-public-rt"
      Environment = var.environment
      Tier        = "Public"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Private routing — default route via NAT Gateway when NAT is enabled. With
# multi-AZ NAT each private subnet gets its own table so traffic stays in-AZ.
# ---------------------------------------------------------------------------
resource "aws_route_table" "private" {
  count  = local.private_route_table_count
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
      Name        = "${local.name_prefix}-private-rt-${count.index + 1}"
      Environment = var.environment
      Tier        = "Private"
    }
  )
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[local.shared_private_route_table ? 0 : count.index].id
}
