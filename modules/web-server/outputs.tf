output "instance_ids" {
  description = "IDs of the web server instances."
  value       = aws_instance.web[*].id
}

output "public_ips" {
  description = "Public IP addresses of the web server instances."
  value       = aws_instance.web[*].public_ip
}

output "private_ips" {
  description = "Private IP addresses of the web server instances."
  value       = aws_instance.web[*].private_ip
}

output "public_dns" {
  description = "Public DNS names of the web server instances."
  value       = aws_instance.web[*].public_dns
}

output "web_urls" {
  description = "Ready-to-open URLs for each web server."
  value       = [for i in aws_instance.web : "http://${i.public_ip}:${var.http_port}"]
}

output "security_group_id" {
  description = "ID of the security group protecting the web servers."
  value       = aws_security_group.web.id
}

output "vpc_id" {
  description = "VPC the web servers were deployed into."
  value       = local.vpc_id
}

output "ami_id" {
  description = "AMI used to launch the web servers."
  value       = local.ami_id
}

output "name_prefix" {
  description = "Computed name prefix (\"<name>-<environment>\") used for resource naming."
  value       = local.name_prefix
}

output "instance_summary" {
  description = "Per-instance map of id, public IP and availability zone."
  value = {
    for i in aws_instance.web : i.tags["Name"] => {
      id                = i.id
      public_ip         = i.public_ip
      private_ip        = i.private_ip
      availability_zone = i.availability_zone
      instance_type     = i.instance_type
    }
  }
}
