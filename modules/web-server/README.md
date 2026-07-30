# Terraform Module: `web-server`

A reusable module that provisions a small fleet of Amazon Linux 2023 web servers
(Apache `httpd`) behind a dedicated security group. Every input is optional
except `name` and `environment`, so the module is usable in one line but still
tunable per environment.

## What it creates

| Resource | Purpose |
| --- | --- |
| `aws_instance.web` (× `instance_count`) | Web server nodes, spread across the available subnets |
| `aws_security_group.web` | Allows inbound HTTP (and optionally SSH), all outbound |

Data sources are used to discover the default VPC, its subnets and the latest
Amazon Linux 2023 AMI, so the module works in a fresh account with no inputs
beyond a name and an environment.

## Usage

### Minimal

```hcl
module "web" {
  source = "./modules/web-server"

  name        = "ironhack-web"
  environment = "dev"
}
```

### Production-style

```hcl
module "web_prod" {
  source = "./modules/web-server"

  name        = "ironhack-web"
  environment = "prod"

  instance_count             = 2
  instance_type              = "t3.small"
  root_volume_size           = 10
  enable_detailed_monitoring = true
  allowed_http_cidr_blocks   = ["0.0.0.0/0"]

  tags = {
    CostCenter = "operations"
    Tier       = "production"
  }
}
```

### Deploying into an existing VPC with SSH access

```hcl
module "web" {
  source = "./modules/web-server"

  name        = "ironhack-web"
  environment = "staging"

  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-aaa", "subnet-bbb"]

  enable_ssh              = true
  allowed_ssh_cidr_blocks = ["203.0.113.10/32"] # never 0.0.0.0/0
  key_name                = "my-keypair"
}
```

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | :---: |
| `name` | Base name for all resources (3–32 chars, lowercase/numbers/hyphens) | `string` | — | **yes** |
| `environment` | Environment: `dev`, `staging` or `prod` | `string` | — | **yes** |
| `instance_count` | Number of web servers (1–10) | `number` | `1` | no |
| `instance_type` | EC2 instance type | `string` | `"t3.micro"` | no |
| `ami_id` | AMI to launch; `null` selects the latest Amazon Linux 2023 | `string` | `null` | no |
| `vpc_id` | VPC to deploy into; `null` uses the default VPC | `string` | `null` | no |
| `subnet_ids` | Subnets to spread across; empty uses all subnets in the VPC | `list(string)` | `[]` | no |
| `http_port` | Port the web server listens on (1–65535) | `number` | `80` | no |
| `allowed_http_cidr_blocks` | CIDRs allowed to reach HTTP (must be non-empty) | `list(string)` | `["0.0.0.0/0"]` | no |
| `enable_ssh` | Open port 22 on the security group | `bool` | `false` | no |
| `allowed_ssh_cidr_blocks` | CIDRs allowed to reach SSH (may not contain `0.0.0.0/0`) | `list(string)` | `[]` | no |
| `key_name` | Existing EC2 key pair to attach | `string` | `null` | no |
| `associate_public_ip` | Assign a public IP to each instance | `bool` | `true` | no |
| `root_volume_size` | Encrypted gp3 root volume size in GiB (8–100) | `number` | `8` | no |
| `enable_detailed_monitoring` | Enable 1-minute CloudWatch monitoring | `bool` | `false` | no |
| `server_message` | Headline rendered on the default page | `string` | `"Hello from Terraform!"` | no |
| `tags` | Additional tags applied to every resource | `map(string)` | `{}` | no |

### Input validation

The module fails fast at plan time rather than at apply time:

- `name` must match `^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$`
- `environment` must be one of `dev`, `staging`, `prod`
- `instance_count` must be 1–10
- `instance_type` must look like a real EC2 type (`family.size`)
- `http_port` must be 1–65535
- `allowed_http_cidr_blocks` must contain at least one entry
- `allowed_ssh_cidr_blocks` must **not** contain `0.0.0.0/0`
- `root_volume_size` must be 8–100 GiB

## Outputs

| Name | Description |
| --- | --- |
| `instance_ids` | List of EC2 instance IDs |
| `public_ips` | List of public IP addresses |
| `private_ips` | List of private IP addresses |
| `public_dns` | List of public DNS names |
| `web_urls` | Ready-to-open `http://<ip>:<port>` URLs |
| `security_group_id` | ID of the web security group |
| `vpc_id` | VPC the servers were deployed into |
| `ami_id` | AMI actually used |
| `name_prefix` | Computed `"<name>-<environment>"` prefix |
| `instance_summary` | Map keyed by instance name → id, IPs, AZ, instance type |

## Naming and tagging

Every resource is named `<name>-<environment>` (instances get a `-N` suffix) and
tagged with `Name`, `Environment`, `Module = "web-server"`, `ManagedBy = "Terraform"`,
merged with any caller-supplied `tags`.

## Security defaults

- **IMDSv2 required** (`http_tokens = "required"`) on all instances
- **Encrypted gp3 root volumes**
- **SSH closed by default**, and validation blocks opening it to the world
- Security group uses `create_before_destroy` to avoid dependency deadlocks on replacement

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.6.0 |
| aws provider | >= 5.0 |

## Notes

- `user_data_replace_on_change = true` means editing `server_message` (or any
  other templated value) replaces the instances rather than silently leaving the
  old page in place.
- Instances are distributed across subnets with `element(...)`, so
  `instance_count` values greater than the subnet count wrap around.
- A `/health` endpoint returning `ok` is provisioned for smoke tests.
