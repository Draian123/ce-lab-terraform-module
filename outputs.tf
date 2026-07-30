# ---------------------------------------------------------------------------
# Dev environment outputs (re-exported from the module)
# ---------------------------------------------------------------------------
output "dev_vpc_id" {
  description = "ID of the dev VPC."
  value       = module.vpc_dev.vpc_id
}

output "dev_vpc_cidr" {
  description = "CIDR block of the dev VPC."
  value       = module.vpc_dev.vpc_cidr
}

output "dev_public_subnets" {
  description = "Public subnet IDs in the dev VPC."
  value       = module.vpc_dev.public_subnet_ids
}

output "dev_private_subnets" {
  description = "Private subnet IDs in the dev VPC."
  value       = module.vpc_dev.private_subnet_ids
}

output "dev_internet_gateway_id" {
  description = "Internet Gateway attached to the dev VPC."
  value       = module.vpc_dev.internet_gateway_id
}

output "dev_nat_gateway_ids" {
  description = "NAT Gateway IDs in the dev VPC (single NAT)."
  value       = module.vpc_dev.nat_gateway_ids
}

output "dev_private_route_table_ids" {
  description = "Private route table IDs in the dev VPC."
  value       = module.vpc_dev.private_route_table_ids
}

# ---------------------------------------------------------------------------
# Prod environment outputs (re-exported from the module)
# ---------------------------------------------------------------------------
output "prod_vpc_id" {
  description = "ID of the prod VPC."
  value       = module.vpc_prod.vpc_id
}

output "prod_vpc_cidr" {
  description = "CIDR block of the prod VPC."
  value       = module.vpc_prod.vpc_cidr
}

output "prod_public_subnets" {
  description = "Public subnet IDs in the prod VPC."
  value       = module.vpc_prod.public_subnet_ids
}

output "prod_private_subnets" {
  description = "Private subnet IDs in the prod VPC."
  value       = module.vpc_prod.private_subnet_ids
}

output "prod_internet_gateway_id" {
  description = "Internet Gateway attached to the prod VPC."
  value       = module.vpc_prod.internet_gateway_id
}

output "prod_nat_gateway_ids" {
  description = "NAT Gateway IDs in the prod VPC (one per AZ)."
  value       = module.vpc_prod.nat_gateway_ids
}

output "prod_private_route_table_ids" {
  description = "Private route table IDs in the prod VPC (one per AZ)."
  value       = module.vpc_prod.private_route_table_ids
}

# ---------------------------------------------------------------------------
# Combined view — same module, two very different shapes
# ---------------------------------------------------------------------------
output "all_environments" {
  description = "Per-environment summary of everything the module created."
  value = {
    dev  = module.vpc_dev.summary
    prod = module.vpc_prod.summary
  }
}
