# SES Product Rule Cleanup Plan

## Executive summary

`shared-ses-infra` now owns the live shared SES receipt rule set and the two live route rules:

- `shared-inbound-mail-rules`
- `gtd-inbound`
- `music-submission`

Live SES also still contains two inactive product-local rule sets:

- `gtd-rules`
- `lush-aural-treats-rules`

Those inactive rule sets duplicate the same routes and actions, but they are not the active regional rule set. The safest cleanup strategy is:

1. Leave the inactive product-local rule sets/rules in place until each product root is initialized against its intended backend and state ownership is confirmed.
2. In a later cleanup pass, remove only duplicate receipt rule/rule-set Terraform ownership from Namaste and Lush using `removed` blocks with `destroy = false`, if state confirms those resources are owned by the product roots.
3. Keep app-local SES support resources in the product repos for now: identities/DKIM/DNS, raw buckets, bucket policies, Lambda forwarders, Lambda permissions, IAM, SSM secrets, and parser endpoints.

Do not delete live inactive rule sets until shared routing has been stable and rollback needs are explicitly retired.

## Namaste product-local SES rule inventory

Inspected:

- `namaste/infrastructure/terraform/email.tf`
- `namaste/infrastructure/terraform/README.md`
- `namaste/infrastructure/terraform/ses-router/main.tf`
- `namaste/infrastructure/terraform/ses-router/README.md`
- `namaste/infrastructure/terraform/ses-router/variables.tf`

Current product AWS root resources:

- `aws_ses_receipt_rule_set.main`
  - provider: `aws.ses`
  - rule set name: `${var.name}-rules`
  - expected prod name: `gtd-rules`
- `aws_ses_receipt_rule.inbound`
  - provider: `aws.ses`
  - rule name: `${var.name}-inbound`
  - expected prod name: `gtd-inbound`
  - recipient: `parse.${var.cloudflare_domain}`
  - expected prod recipient: `parse.namasteapp.tech`
  - S3 action: `aws_s3_bucket.ses_emails.bucket`
  - Lambda action: `aws_lambda_function.ses_forwarder.arn`
- `removed` block for prior `aws_ses_active_receipt_rule_set.main`
  - `destroy = false`
  - keeps Terraform from deactivating the live regional active rule set while dropping old active-rule-set state binding

Current Namaste `ses-router` root:

- `aws_ses_receipt_rule_set.regional`
- `aws_ses_receipt_rule.namaste`
- `aws_ses_receipt_rule.lush`
- `aws_ses_active_receipt_rule_set.regional`

That root is now legacy/superseded by `shared-ses-infra`. It must not be applied unless deliberately rolling back or performing a reviewed migration.

## Lush product-local SES rule inventory

Inspected:

- `lush-aural-treats/infrastructure/email.tf`
- `lush-aural-treats/infrastructure/variables.tf`
- `lush-aural-treats/infrastructure/README.md`
- `lush-aural-treats/infrastructure/main.tf`

Current product AWS root resources:

- `aws_ses_receipt_rule_set.main`
  - provider: `aws.ses`
  - rule set name: `${var.name}-rules`
  - expected prod name: `lush-aural-treats-rules`
- `aws_ses_active_receipt_rule_set.main`
  - `count = var.manage_ses_active_rule_set ? 1 : 0`
  - `manage_ses_active_rule_set` defaults to `false`
  - should remain false unless deliberately rolling back or performing a reviewed migration
- `aws_ses_receipt_rule.music_submission`
  - provider: `aws.ses`
  - rule name: `music-submission`
  - recipient: `parse.${var.dns_name}`
  - expected prod recipient: `parse.lushauraltreats.com`
  - S3 action: `aws_s3_bucket.ses_emails.bucket`
  - Lambda action: `aws_lambda_function.ses_forwarder.arn`

No SES-specific `removed` block is currently present in Lush. The only inspected `removed` block in the root is for the old DynamoDB tracks table and is unrelated to SES.

## shared-ses-infra ownership confirmation

Inspected:

- `shared-ses-infra/infrastructure/aws/main.tf`
- `shared-ses-infra/infrastructure/aws/outputs.tf`
- `shared-ses-infra/README.md`

Terraform configuration owns only the shared receipt rule set and two receipt rules:

- `module.ses_receipt_rule_set`
  - `source = github.com/jch254/terraform-modules//ses-receipt-rule-set?ref=1.6.0`
  - `name = "shared-inbound-mail-rules"`
  - `activate = false`
- `module.gtd_inbound_rule`
  - `source = github.com/jch254/terraform-modules//ses-receipt-rule?ref=1.6.0`
  - `name = "gtd-inbound"`
  - `rule_set_name = module.ses_receipt_rule_set.name`
  - recipient: `parse.namasteapp.tech`
  - S3 bucket: `gtd-ses-emails`
  - Lambda ARN: `arn:aws:lambda:ap-southeast-2:352311918919:function:gtd-ses-forwarder`
- `module.music_submission_rule`
  - `source = github.com/jch254/terraform-modules//ses-receipt-rule?ref=1.6.0`
  - `name = "music-submission"`
  - `rule_set_name = module.ses_receipt_rule_set.name`
  - recipient: `parse.lushauraltreats.com`
  - S3 bucket: `lush-aural-treats-ses-emails`
  - Lambda ARN: `arn:aws:lambda:ap-southeast-2:352311918919:function:lush-aural-treats-ses-forwarder`

Read-only state check in `shared-ses-infra/infrastructure/aws` confirmed these addresses:

```text
module.gtd_inbound_rule.aws_ses_receipt_rule.main
module.music_submission_rule.aws_ses_receipt_rule.main
module.ses_receipt_rule_set.aws_ses_receipt_rule_set.main
```

Read-only plan result:

```text
No changes. Your infrastructure matches the configuration.
```

`shared-ses-infra` still does not manage:

- `aws_ses_active_receipt_rule_set`
- SES identities/DKIM
- Cloudflare DNS
- raw buckets
- bucket policies
- Lambda forwarders
- Lambda permissions
- IAM roles/policies
- app parser behavior

## Live SES rule-set state

Commands run:

```bash
aws ses list-receipt-rule-sets --region ap-southeast-2
aws ses describe-active-receipt-rule-set --region ap-southeast-2
aws ses describe-receipt-rule-set --rule-set-name gtd-rules --region ap-southeast-2
aws ses describe-receipt-rule-set --rule-set-name lush-aural-treats-rules --region ap-southeast-2
```

Live rule sets:

- `gtd-rules`
- `lush-aural-treats-rules`
- `shared-inbound-mail-rules`

Active rule set:

- `shared-inbound-mail-rules`

Active rules:

- `gtd-inbound`
  - enabled: `true`
  - scan enabled: `true`
  - TLS policy: `Optional`
  - recipient: `parse.namasteapp.tech`
  - action 1: S3 bucket `gtd-ses-emails`
  - action 2: Lambda `arn:aws:lambda:ap-southeast-2:352311918919:function:gtd-ses-forwarder`
  - Lambda invocation: `Event`
- `music-submission`
  - enabled: `true`
  - scan enabled: `true`
  - TLS policy: `Optional`
  - recipient: `parse.lushauraltreats.com`
  - action 1: S3 bucket `lush-aural-treats-ses-emails`
  - action 2: Lambda `arn:aws:lambda:ap-southeast-2:352311918919:function:lush-aural-treats-ses-forwarder`
  - Lambda invocation: `Event`

Inactive product-local rule sets:

- `gtd-rules`
  - contains enabled rule `gtd-inbound`
  - same recipient/action shape as the shared Namaste route
  - inactive because the active rule set is `shared-inbound-mail-rules`
- `lush-aural-treats-rules`
  - contains enabled rule `music-submission`
  - same recipient/action shape as the shared Lush route
  - inactive because the active rule set is `shared-inbound-mail-rules`

## Product Terraform plan findings

No Namaste or Lush product plan was run in this pass.

Reason:

- `namaste/infrastructure/terraform` has no local `.terraform/` initialization artifacts.
- `lush-aural-treats/infrastructure` has no local `.terraform/` initialization artifacts.
- The task allowed plan-only checks only if roots were safely initialized. For this read-only cleanup planning pass, the product roots were not initialized or reconfigured, to avoid accidental backend/local-state ambiguity.

Available tfvars:

- Namaste AWS root: `namaste/infrastructure/terraform/environments/prod/terraform.tfvars`
- Namaste legacy router root: `namaste/infrastructure/terraform/ses-router/environments/prod/terraform.tfvars`
- Lush AWS root: `lush-aural-treats/infrastructure/environments/prod/terraform.tfvars`

Future plan-only checks should initialize each root against its intended backend before running `terraform state list` or `terraform plan`.

## Recommended cleanup strategy

### Immediate recommendation

Choose Option A for now: leave inactive product-local rule set/rule resources in config and in AWS until state ownership is confirmed.

Rationale:

- The inactive product-local rule sets do not currently receive mail because `shared-inbound-mail-rules` is active.
- They provide rollback insurance while the shared ownership boundary is still fresh.
- Product roots have not yet been checked against remote state in this pass.
- App-local buckets, Lambdas, permissions, IAM, identities, DNS, secrets, and parsers still belong in the product repos.

### Next cleanup recommendation

After product roots are initialized against their intended remote backends and state confirms ownership, choose Option C leading to Option B:

1. Add Terraform `removed` blocks with `destroy = false` for duplicate product-local receipt rules.
2. Add Terraform `removed` blocks with `destroy = false` for duplicate product-local receipt rule sets.
3. Run product-root plans and confirm Terraform will forget state bindings without destroying live resources.
4. Apply only after review if the plan shows no live SES destruction or active rule set change.
5. Leave the inactive AWS rule sets in place temporarily as rollback insurance.
6. Later, after a separate approval, manually delete inactive product-local rule sets only if rollback no longer needs them.

Do not choose Option D as the primary cleanup path. Keeping a product-local rule set but removing only its rule leaves a less useful rollback shape and does not materially improve shared routing safety.

Do not block this cleanup on Option E. Identity/DNS/bucket migration is independent and higher blast radius. Keep those resources app-local until separately planned.

## Future commands, if any

Do not run these in the current pass. These are for a future cleanup window.

### Namaste product AWS root checks

```bash
cd namaste/infrastructure/terraform
terraform init \
  -reconfigure \
  -backend-config "bucket=jch254-terraform-remote-state" \
  -backend-config "key=gtd" \
  -backend-config "region=ap-southeast-4"

terraform state list | rg 'aws_ses_receipt_rule|aws_ses_receipt_rule_set|aws_ses_active_receipt_rule_set'

terraform plan \
  -refresh=false \
  -input=false \
  -no-color \
  -var-file=environments/prod/terraform.tfvars
```

If state confirms ownership and cleanup is approved, add removed blocks similar to:

```hcl
removed {
  from = aws_ses_receipt_rule.inbound

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_ses_receipt_rule_set.main

  lifecycle {
    destroy = false
  }
}
```

Then run:

```bash
terraform plan \
  -refresh=false \
  -input=false \
  -no-color \
  -var-file=environments/prod/terraform.tfvars
```

Only after a reviewed clean cleanup plan should a future pass consider apply.

### Namaste legacy ses-router root checks

```bash
cd namaste/infrastructure/terraform/ses-router
terraform init \
  -reconfigure \
  -backend-config "bucket=jch254-terraform-remote-state" \
  -backend-config "key=ses-router/ap-southeast-2" \
  -backend-config "region=ap-southeast-4"

terraform state list
terraform plan -input=false -no-color -var-file=environments/prod/terraform.tfvars
```

If this root has remote state for resources now owned by `shared-ses-infra`, do not apply it. Plan a separate state retirement path.

### Lush product AWS root checks

```bash
cd lush-aural-treats/infrastructure
terraform init -reconfigure

terraform state list | rg 'aws_ses_receipt_rule|aws_ses_receipt_rule_set|aws_ses_active_receipt_rule_set'

terraform plan \
  -refresh=false \
  -input=false \
  -no-color \
  -var-file=environments/prod/terraform.tfvars
```

If state confirms ownership and cleanup is approved, add removed blocks similar to:

```hcl
removed {
  from = aws_ses_receipt_rule.music_submission

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_ses_receipt_rule_set.main

  lifecycle {
    destroy = false
  }
}
```

Do not add or enable a `removed` block for `aws_ses_active_receipt_rule_set.main` unless state proves it is still present. Because `manage_ses_active_rule_set = false`, this resource should not be created by the current config.

Then run:

```bash
terraform plan \
  -refresh=false \
  -input=false \
  -no-color \
  -var-file=environments/prod/terraform.tfvars
```

Only after a reviewed clean cleanup plan should a future pass consider apply.

### Shared verification commands for any future cleanup

```bash
cd shared-ses-infra/infrastructure/aws
terraform plan -input=false -no-color

aws ses describe-active-receipt-rule-set --region ap-southeast-2
dig MX parse.namasteapp.tech
dig MX parse.lushauraltreats.com
```

## Stop conditions

Stop before any future cleanup apply if:

- any plan wants to destroy or replace `shared-inbound-mail-rules`
- any plan wants to destroy or replace `gtd-inbound` or `music-submission` in `shared-inbound-mail-rules`
- any plan changes or deactivates the active SES receipt rule set
- the active receipt rule set is not `shared-inbound-mail-rules`
- either parse domain route is missing from the active rule set
- S3 first / Lambda second action order changes unexpectedly
- Lambda invocation type changes from `Event`
- Terraform state ownership is unclear or split between product roots and `shared-ses-infra`
- product roots show drift in app-local buckets, bucket policies, Lambda permissions, IAM, secrets, or forwarder Lambdas
- Namaste or Lush parser endpoints or parser auth would change
- Lush work broadens beyond SES routing cleanup
- Cloudflare MX/TXT/DKIM records would change
- any cleanup requires importing, moving, or removing state without an explicit reviewed state plan

Stop after any future cleanup apply if:

- `shared-ses-infra` no longer has a clean plan
- `aws ses describe-active-receipt-rule-set --region ap-southeast-2` differs from the expected shared route shape
- either app stops receiving inbound mail through its app-local forwarder/parser path
