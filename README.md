# terraform-iac-aws

Multi-environment AWS infrastructure (VPC, ECS Fargate, RDS Postgres, S3) provisioned with
reusable Terraform modules, one isolated state file per environment, and a GitHub Actions
pipeline that plans on every PR and applies on merge — with a manual approval gate in front
of prod.

## Module structure

```
modules/
  vpc/           # public + private subnets, IGW, route tables (no NAT — see Cost decisions)
  ecs-fargate/   # ECS cluster, task def, service, execution IAM role, SG, log group
  rds/           # Postgres RDS instance, subnet group, SG, generated master password
  s3/            # private, encrypted, versioned bucket

envs/
  dev/           # root module: wires the 4 modules together for dev
  stage/         # same wiring, stage-sized inputs and isolated state
  prod/          # same wiring, prod-sized inputs and isolated state

bootstrap/       # one-time: creates the S3 bucket + DynamoDB table used as the backend
.github/workflows/
  terraform-plan.yml   # PR: plan changed env(s), post the plan as a PR comment
  terraform-apply.yml  # main: apply changed env(s), prod gated by required reviewer
```

Each `envs/<env>` directory is its own Terraform root module — same modules, different
inputs (`terraform.tfvars`) and a different state file. There is no shared root `main.tf`;
this is the directory-per-env layout, chosen over a single root + `-var-file` because it
maps 1:1 to "one plan, one state, one environment" and is easier to reason about in CI.

## Environment isolation

- Each environment has its own VPC CIDR (`10.0.0.0/16` dev, `10.1.0.0/16` stage,
  `10.2.0.0/16` prod) — no shared networking.
- Each environment has its own Terraform state object: `s3://<state-bucket>/dev|stage|prod/terraform.tfstate`,
  same bucket, same DynamoDB lock table, different key. A `terraform apply` in one
  environment can never touch another's state.
- Nothing is parameterized by a workspace — there's no `terraform workspace select` step
  anywhere, on purpose. Workspaces make it easy to accidentally apply the wrong environment;
  separate directories make the target explicit in the file path.

## Cost decisions

- **No NAT gateway or NAT instance.** ECS Fargate tasks run in the public subnets with a
  public IP (no ALB either — ~$16/mo not needed for this demo). RDS sits in the private
  subnets; it doesn't need outbound internet access, so the private route table has no
  default route at all.
- **RDS**: `db.t3.micro`, 20GB gp2, single-AZ, `backup_retention_period = 0`,
  `deletion_protection = false`, `skip_final_snapshot = true` — smallest footprint, and
  torn down cleanly without manual snapshot cleanup.
- **ECS**: smallest Fargate task size (256 CPU / 512 MB), `desired_count = 1`.
- **S3**: no lifecycle rules, no replication — a plain private bucket.
- RDS master password is a `random_password` resource, output as sensitive. Fine for a
  demo; a real deployment would use Secrets Manager or `manage_master_user_password`.

## Remote state backend

`bootstrap/` is a standalone Terraform config (local state, run once) that creates the S3
bucket and DynamoDB lock table every environment's backend points at:

```bash
cd bootstrap
terraform init
terraform apply
terraform output state_bucket_name
terraform output lock_table_name
```

Each `envs/<env>/backend.tf` only hardcodes the state `key` (env-specific); bucket, region,
and lock table are supplied at `terraform init` time via `-backend-config`, so the
account-specific bucket name is never committed:

```bash
cd envs/dev
terraform init \
  -backend-config="bucket=<state_bucket_name>" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=<lock_table_name>"
terraform apply
```

## CI pipeline

**On PR** (`terraform-plan.yml`): detects which of `envs/dev|stage|prod` changed (a change
under `modules/` plans all three, since it's shared), runs `terraform plan` for each, and
posts the plan as a collapsible PR comment per environment.

**On merge to main** (`terraform-apply.yml`): same env-detection, then `terraform apply
-auto-approve` per environment, one at a time (`max-parallel: 1`), in `dev → stage → prod`
order. Each apply job runs under a GitHub Environment named after the Terraform environment
(`dev` / `stage` / `prod`). `prod` has a required-reviewer protection rule, so that job
pauses and waits for a human to click **Approve** before it's allowed to run.

### One-time repo setup

```bash
# Repo variables (not secret — used to point terraform init at the backend)
gh variable set TF_STATE_BUCKET --body "<state_bucket_name>"
gh variable set TF_STATE_TABLE  --body "<lock_table_name>"

# Repo secret used by the plan workflow (read-only IAM user is enough)
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY

# Same two secrets, set per-environment (Settings → Environments) for apply.
# The "prod" environment additionally needs a required reviewer configured
# under Settings → Environments → prod → Protection rules.
```

### Screenshots

_Added after running the pipeline against a real AWS account:_

- PR plan comment: `docs/screenshot-pr-plan.png`
- Approved prod apply (required reviewer gate): `docs/screenshot-prod-approval.png`

## Cost control / teardown

Every environment was destroyed immediately after the screenshots above were captured:

```bash
cd envs/<env>
terraform destroy
```

`bootstrap/` (the state bucket + lock table) was left in place since it holds no billable
resources beyond a few KB of S3/DynamoDB.

## Resume bullet

> Built a multi-environment AWS platform (VPC, ECS Fargate, RDS, S3) with reusable Terraform
> modules, isolated per-environment remote state (S3 + DynamoDB locking), and a GitHub
> Actions pipeline that posts `terraform plan` output on every PR and gates production
> `apply` behind a manual approval step.
