# Example: consume the VPC module from Git

Step 10 of the lab. A standalone configuration (its own state) that sources the module from GitHub
at a pinned tag instead of a local path:

```hcl
source = "github.com/Draian123/ce-lab-terraform-module//modules/vpc?ref=v1.0.0"
```

The `//` separates the repository from the sub-directory inside it, and `?ref=` pins the version —
a downstream plan cannot change because someone pushed to `main`.

## Run it

```bash
cd examples/vpc-from-git
terraform init    # clones the module from GitHub at tag v1.0.0
terraform plan
```

`enable_nat_gateway = false`, so applying this example creates only free resources (VPC, 4 subnets,
IGW, 2 route tables, 4 associations — 12 in total). The private subnets have no default route,
which is the intended "fully isolated" shape.

`terraform init` reports the resolved source in `.terraform/modules/modules.json`:

```json
{"Key":"vpc","Source":"git::https://github.com/Draian123/ce-lab-terraform-module.git//modules/vpc?ref=v1.0.0"}
```

## Note on `environment`

The lab snippet passes `environment = "test"`. The module's validation only accepts `dev`,
`staging` or `prod`, so this example uses `dev` — the validation working as designed.
