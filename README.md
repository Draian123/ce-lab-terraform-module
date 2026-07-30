# Lab M4.05 - Create Your First Terraform Module

**Course:** Cloud Engineering Bootcamp - Week 4 (Infrastructure as Code with Terraform)
**Lab:** M4.05 - Create Your First Terraform Module (Unit 4.2.4)
**Status:** ✅ Complete — VPC module built, deployed to dev + prod, verified against AWS, destroyed, tagged `v1.0.0`

The verbatim lab brief is kept in [`LAB-INSTRUCTIONS.md`](LAB-INSTRUCTIONS.md).

## 🎯 Objectives

- Create a reusable Terraform module
- Define module inputs (variables) and outputs
- Structure module files properly
- Use the module in multiple environments
- Understand module composition patterns
- Version and document modules

## 📁 Repository structure

```
ce-lab-terraform-module/
├── README.md                   <- this file (lab writeup)
├── LAB-INSTRUCTIONS.md         <- the lab brief, copied from the Ironhack portal
├── main.tf                     <- root config: calls the vpc module twice (dev + prod)
├── variables.tf                <- root inputs (region, project name, AZs)
├── outputs.tf                  <- root outputs re-exported from both module instances
├── example.tfvars              <- sample variable values
├── .gitignore                  <- excludes .terraform/, state files, *.tfvars
├── modules/
│   ├── vpc/                    <- ⭐ the module this lab is about
│   │   ├── main.tf             <- VPC, subnets, IGW, NAT GWs, route tables
│   │   ├── variables.tf        <- 9 inputs, 6 with validation rules
│   │   ├── outputs.tf          <- 15 outputs
│   │   └── README.md           <- module documentation (inputs/outputs/usage)
│   └── web-server/             <- earlier module from the M4.05 warm-up (see below)
├── examples/
│   └── vpc-from-git/           <- step 10: consuming the module from GitHub at ?ref=v1.0.0
├── logs/                       <- captured command output from the run
└── screenshots/                <- browser captures (from the web-server warm-up)
```

## 🧩 The module: `vpc`

`modules/vpc` provisions a multi-AZ VPC: public and private subnets, an Internet Gateway,
zero/one/N NAT Gateways with their Elastic IPs, and the matching route tables and associations.
Full reference documentation lives in [`modules/vpc/README.md`](modules/vpc/README.md).

Design decisions worth calling out:

- **One flag pair, three topologies.** `enable_nat_gateway` and `single_nat_gateway` combine into
  disabled / single-shared / one-NAT-per-AZ. The private route table count follows automatically,
  so multi-AZ NAT means each private subnet egresses through the NAT Gateway *in its own AZ* — no
  cross-AZ data charges and no shared failure domain.
- **Counts derived in `locals`, not inlined.** `local.nat_gateway_count` and
  `local.private_route_table_count` are computed once and reused. The lab's snippet repeated the
  same ternary in four places and, with `enable_nat_gateway = false`, indexed
  `aws_route_table.private[count.index]` into a list of length 1 — that combination fails. The
  `local.shared_private_route_table` flag fixes the association index, which is what makes the
  step-10 example (`enable_nat_gateway = false`) actually work.
- **Validation over documentation.** 6 of the 9 inputs carry `validation` blocks (valid CIDRs,
  allowed environment names, at least 2 AZs and 2 subnets per tier), plus a `precondition` on the
  VPC asserting there are enough AZs for the subnet lists. Bad input fails at plan time.
- **`dynamic "route"`.** The private route table's default route only renders when NAT is enabled,
  so a NAT-less VPC gets genuinely isolated private subnets rather than a broken route.
- **Consistent tagging.** Every resource merges `var.tags` with a computed `Name`,
  `Environment`, and a `Tier` of `Public`/`Private` where it's meaningful.
- **Rich outputs.** Beyond raw IDs, the module exposes `nat_public_ips`, `name_prefix` and a
  `summary` object (subnet counts, AZs, NAT mode) that the root config prints per environment.

## 🔀 Multi-environment usage

`main.tf` calls the *same* module twice with different inputs — this is the core of the lab.
Nothing about the module changes between environments; only the arguments do.

| Setting | `module "vpc_dev"` | `module "vpc_prod"` |
| --- | --- | --- |
| `environment` | `dev` | `prod` |
| `vpc_cidr` | `10.0.0.0/16` | `10.1.0.0/16` |
| `public_subnet_cidrs` | `10.0.1.0/24`, `10.0.2.0/24` | `10.1.1.0/24`, `10.1.2.0/24` |
| `private_subnet_cidrs` | `10.0.11.0/24`, `10.0.12.0/24` | `10.1.11.0/24`, `10.1.12.0/24` |
| `single_nat_gateway` | `true` (cost savings) | `false` (HA) |
| NAT Gateways created | 1 | 2 |
| Private route tables | 1 shared | 2, one per AZ |
| `tags` | `Owner = DevTeam` | `Owner = PlatformTeam`, `Compliance = SOC2` |
| Resulting name prefix | `ironhack-vpc-dev` | `ironhack-vpc-prod` |
| Resources created | 14 | 17 |

Both module instances live in one root module, so a single `terraform apply` builds both
environments and a single `terraform destroy` tears both down. Provider-level `default_tags`
stamps `Project`, `Lab` and `ManagedBy` onto every resource in both.

## 🚀 How to run

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform destroy -auto-approve
```

> 💸 **Cost warning:** this configuration creates **3 NAT Gateways** (1 dev + 2 prod). NAT Gateways
> bill hourly plus per-GB, and they are *not* free-tier eligible. Destroy when you're done; the run
> documented below was applied, verified and destroyed inside ~15 minutes.

## 📋 Execution results

### 1. Init, format, validate

```
Initializing modules...
- vpc_prod in modules\vpc
- vpc_dev in modules\vpc
...
Terraform has been successfully initialized!
```

`terraform fmt -recursive` changed nothing (all files already canonical);
`terraform validate` returned `Success! The configuration is valid.`
(`logs/00-fmt-and-validate.log`, `logs/01-terraform-init.log`)

### 2. Plan

```
Plan: 31 to add, 0 to change, 0 to destroy.
```

Two module calls → 31 resources. The asymmetry between them is visible in the plan addresses:

```
module.vpc_dev.aws_nat_gateway.main[0]          module.vpc_prod.aws_nat_gateway.main[0]
                                                module.vpc_prod.aws_nat_gateway.main[1]
module.vpc_dev.aws_route_table.private[0]      module.vpc_prod.aws_route_table.private[0]
                                                module.vpc_prod.aws_route_table.private[1]
```

(`logs/02-terraform-plan.log`)

### 3. Apply

`Apply complete! Resources: 31 added, 0 changed, 0 destroyed.` (`logs/03-terraform-apply.log`)

Outputs produced:

```
dev_vpc_id  = "vpc-0babc9b9892a5f426"   (10.0.0.0/16)
prod_vpc_id = "vpc-04d4762f9a3362fc4"   (10.1.0.0/16)

all_environments = {
  dev  = { nat_gateways = 1, nat_mode = "single",   public_subnets = 2, private_subnets = 2, availability_zones = ["us-east-1a","us-east-1b"] }
  prod = { nat_gateways = 2, nat_mode = "multi-az", public_subnets = 2, private_subnets = 2, availability_zones = ["us-east-1a","us-east-1b"] }
}
```

(`logs/05-outputs-and-state.log`)

### 4. AWS verification

Both VPCs, all 8 subnets, both IGWs and all 3 NAT Gateways confirmed via the AWS CLI
(`logs/06-aws-cli-verification.log`):

```
|    Cidr     |  Env  |          Name           |          VpcId          |
+-------------+-------+-------------------------+-------------------------+
|  10.0.0.0/16|  dev  |  ironhack-vpc-dev-vpc   |  vpc-0babc9b9892a5f426  |
|  10.1.0.0/16|  prod |  ironhack-vpc-prod-vpc  |  vpc-04d4762f9a3362fc4  |

|     AZ     | AutoPublicIP  |     Cidr      |            Name              |   Tier    |
+------------+---------------+---------------+------------------------------+-----------+
|  us-east-1a|  True         |  10.0.1.0/24  |  ironhack-vpc-dev-public-1   |  Public   |
|  us-east-1a|  False        |  10.0.11.0/24 |  ironhack-vpc-dev-private-1  |  Private  |
|  us-east-1b|  False        |  10.0.12.0/24 |  ironhack-vpc-dev-private-2  |  Private  |
|  us-east-1b|  True         |  10.0.2.0/24  |  ironhack-vpc-dev-public-2   |  Public   |

|  ironhack-vpc-dev-nat-1 |  nat-0d8fc0b7086636cf0 |  13.223.201.37  |  available |
|  ironhack-vpc-prod-nat-1|  nat-025d6f80cc2a07017 |  34.225.36.178  |  available |
|  ironhack-vpc-prod-nat-2|  nat-0e90ece2ff4b1bb22 |  100.55.108.186 |  available |
```

Subnets landed in **two AZs** (`us-east-1a`, `us-east-1b`) in both environments, public subnets
have `MapPublicIpOnLaunch = true` and private ones don't.

### 5. Routing verification — the part that proves the NAT flags work

Route tables and their default routes (`logs/04-routing-verification.log`):

```
=== dev (single_nat_gateway = true) ===
|          Igw          |              Name               |          Nat           |  Subnets  |
|  None                 |  ironhack-vpc-dev-private-rt-1  |  nat-0d8fc0b7086636cf0 |  2        |
|  igw-07c2214cf71caad64|  ironhack-vpc-dev-public-rt     |  None                  |  2        |

=== prod (single_nat_gateway = false) ===
|  None                 |  ironhack-vpc-prod-private-rt-1  |  nat-025d6f80cc2a07017 |  1        |
|  None                 |  ironhack-vpc-prod-private-rt-2  |  nat-0e90ece2ff4b1bb22 |  1        |
|  igw-02deb94d57808fce2|  ironhack-vpc-prod-public-rt     |  None                  |  2        |
```

Dev: one private route table serving **both** private subnets through **one** NAT Gateway.
Prod: two private route tables, one subnet each, and each one resolves to the NAT Gateway sitting
in the *same* availability zone:

```
prod private subnet-09c449d1a5f0c2c3f (us-east-1a) -> nat-025d6f80cc2a07017 (in us-east-1a)  => same-AZ: YES
prod private subnet-02b5de4d21a074e67 (us-east-1b) -> nat-0e90ece2ff4b1bb22 (in us-east-1b)  => same-AZ: YES
dev  private subnet-04de856ad32ba7673 (us-east-1a) -> nat-0d8fc0b7086636cf0
dev  private subnet-02696d059a3679365 (us-east-1b) -> nat-0d8fc0b7086636cf0
```

### 6. Destroy

`Destroy complete! Resources: 31 destroyed.` (`logs/07-terraform-destroy.log`)

Post-destroy checks all returned `0`: VPCs tagged with this lab, NAT Gateways in
`available`/`pending`, and Elastic IPs on the account — so nothing is still billing.

### 7. Versioning & Git consumption (steps 9-10)

Tagged `v1.0.0` and pushed to <https://github.com/Draian123/ce-lab-terraform-module>.
[`examples/vpc-from-git`](examples/vpc-from-git) is a standalone config that pulls the module
straight from GitHub at that tag:

```hcl
module "vpc" {
  source = "github.com/Draian123/ce-lab-terraform-module//modules/vpc?ref=v1.0.0"
  # ...
  enable_nat_gateway = false   # NAT-free, so this example costs nothing
}
```

`terraform init` in that directory clones the module from the tag, and `terraform plan` produces a
clean 11-resource plan — the module works as a versioned, externally consumable artifact.
Note the lab snippet passes `environment = "test"`, which the module's own validation correctly
rejects (allowed: `dev`, `staging`, `prod`); the example uses `dev`.

## 📦 Also in this repo: the `web-server` module

`modules/web-server/` is a second, fully working module (Amazon Linux 2023 Apache instances +
security group, 17 inputs, 10 outputs) built during an earlier pass at this lab before the VPC
brief was in hand. It is documented in
[`modules/web-server/README.md`](modules/web-server/README.md) and the `screenshots/` folder shows
its instances serving live traffic. It is **not** wired into the root `main.tf` — kept as a second
worked example of the same module patterns.

## 💡 Key takeaways

- A module is just a directory of `.tf` files; `source = "./modules/vpc"` is all it takes to
  consume one locally, and `source = "github.com/...//modules/vpc?ref=v1.0.0"` to consume it
  versioned from Git.
- Module inputs are the contract. Defaults plus `validation` blocks make a module hard to misuse —
  a bad CIDR or a bogus environment name fails at plan time, not two minutes into an apply.
- Boolean feature flags (`enable_nat_gateway`, `single_nat_gateway`) are how one module serves
  dev economics and prod availability without a fork. Derive every dependent count from them in
  `locals` so the flags can't drift out of sync across resources.
- Module outputs are the only way data escapes a module; the root module has to re-export anything
  it wants surfaced (`module.vpc_dev.public_subnet_ids`).
- Resource addresses become `module.<call_name>.<type>.<name>[index]`, which is what keeps two
  instances of the same module from colliding in state.
- Git tags are module versions. Pinning `?ref=v1.0.0` means a downstream project's plan can't
  change because someone pushed to `main`.

## ✅ Grading rubric (100 pts)

| Criterion | Points | Where to find it |
| --- | --- | --- |
| Module structure correct | 15 | `modules/vpc/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| Variables well-defined | 20 | 9 typed inputs with descriptions, sensible defaults, 6 `validation` blocks + a VPC `precondition` |
| Resources implemented | 25 | VPC, 2×2 subnets across 2 AZs, IGW, EIPs, NAT GWs, public + private route tables and associations — applied and verified in AWS |
| Outputs defined | 10 | 15 module outputs incl. `summary`; re-exported as 15 root outputs |
| Used in multiple environments | 15 | `main.tf` calls the module as `vpc_dev` (single NAT) and `vpc_prod` (multi-AZ NAT); differences confirmed via AWS CLI routing checks |
| Documentation complete | 10 | `modules/vpc/README.md` (usage, NAT-mode matrix, input/output/resource tables, cost note) + this writeup |
| Module versioned | 5 | Git tag `v1.0.0` pushed; `examples/vpc-from-git` consumes it via `?ref=v1.0.0` |
