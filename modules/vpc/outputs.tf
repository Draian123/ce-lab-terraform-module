output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.main.arn
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets."
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets."
  value       = aws_subnet.private[*].cidr_block
}

output "availability_zones" {
  description = "Availability zones the subnets were placed in."
  value       = distinct(aws_subnet.public[*].availability_zone)
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways (empty when NAT is disabled)."
  value       = aws_nat_gateway.main[*].id
}

output "nat_public_ips" {
  description = "Elastic IPs attached to the NAT Gateways."
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables."
  value       = aws_route_table.private[*].id
}

output "name_prefix" {
  description = "Prefix used to name every resource in this module instance."
  value       = local.name_prefix
}

output "summary" {
  description = "Human-readable summary of what this module instance created."
  value = {
    vpc_id             = aws_vpc.main.id
    vpc_cidr           = aws_vpc.main.cidr_block
    environment        = var.environment
    availability_zones = distinct(aws_subnet.public[*].availability_zone)
    public_subnets     = length(aws_subnet.public)
    private_subnets    = length(aws_subnet.private)
    nat_gateways       = length(aws_nat_gateway.main)
    nat_mode           = var.enable_nat_gateway ? (var.single_nat_gateway ? "single" : "multi-az") : "disabled"
  }
}
