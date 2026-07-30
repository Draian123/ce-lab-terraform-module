terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  name_prefix = "${var.name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Name        = local.name_prefix
      Environment = var.environment
      Module      = "web-server"
      ManagedBy   = "Terraform"
    }
  )

  # Fall back to the account's default VPC when no vpc_id is supplied.
  vpc_id = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id

  # Fall back to every subnet in the selected VPC when no subnet_ids are supplied.
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : tolist(data.aws_subnets.selected[0].ids)

  # Latest Amazon Linux 2023 AMI unless the caller pins one.
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id
}

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "selected" {
  count = length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_ami" "al2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for ${local.name_prefix} web servers"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr_blocks
  }

  # SSH is opt-in: only rendered when enable_ssh = true.
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []

    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidr_blocks
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "web" {
  count = var.instance_count

  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = element(local.subnet_ids, count.index)
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name

  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y httpd
    systemctl enable --now httpd

    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/placement/availability-zone)

    cat > /var/www/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
      <head><title>${local.name_prefix}</title></head>
      <body>
        <h1>${var.server_message}</h1>
        <p>Environment: <strong>${var.environment}</strong></p>
        <p>Server: <strong>${local.name_prefix}</strong> (node ${count.index + 1} of ${var.instance_count})</p>
        <p>Instance ID: <strong>$INSTANCE_ID</strong></p>
        <p>Availability Zone: <strong>$AZ</strong></p>
        <p>Provisioned by the <em>web-server</em> Terraform module.</p>
      </body>
    </html>
    HTML

    # Lightweight endpoint used by the lab verification step.
    echo "ok" > /var/www/html/health
  EOF

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
    tags        = merge(local.common_tags, { Name = "${local.name_prefix}-${count.index + 1}-root" })
  }

  # Enforce IMDSv2.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring = var.enable_detailed_monitoring

  tags = merge(
    local.common_tags,
    { Name = "${local.name_prefix}-${count.index + 1}" }
  )
}
