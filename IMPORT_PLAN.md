# SES Receipt Rule Import Plan

This plan transfers Terraform state ownership for the existing live SES receipt rule set and two receipt rules into `shared-ses-infra`.

It is documentation only. Do not run these commands until the import window is approved and the AWS root is initialized against the intended shared-ses-infra backend.

## Scope

Region: `ap-southeast-2`

Modeled live resources:

- receipt rule set: `shared-inbound-mail-rules`
- receipt rule: `gtd-inbound`
- receipt rule: `music-submission`

Out of scope for this import:

- `aws_ses_active_receipt_rule_set`
- SES identities and DKIM
- Cloudflare DNS records
- S3 buckets and bucket policies
- Lambda functions, permissions, roles, and policies
- Namaste and Lush app parser behavior

`module.ses_receipt_rule_set` has `activate = false`, so shared-ses-infra does not manage the active receipt rule set in this phase.

## Terraform Addresses And Import IDs

The AWS provider imports `aws_ses_receipt_rule_set` by rule set name.

The AWS provider imports `aws_ses_receipt_rule` by ruleset name and rule name separated by `:`.

| Live resource | Terraform address | Import ID |
| --- | --- | --- |
| `shared-inbound-mail-rules` | `module.ses_receipt_rule_set.aws_ses_receipt_rule_set.main` | `shared-inbound-mail-rules` |
| `gtd-inbound` | `module.gtd_inbound_rule.aws_ses_receipt_rule.main` | `shared-inbound-mail-rules:gtd-inbound` |
| `music-submission` | `module.music_submission_rule.aws_ses_receipt_rule.main` | `shared-inbound-mail-rules:music-submission` |

Provider docs:

- `aws_ses_receipt_rule_set`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule_set
- `aws_ses_receipt_rule`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_receipt_rule

## Pre-Import Checks

Run from `infrastructure/aws`.

Initialize with the intended backend before importing. Do not import into an accidental local state file.

```bash
terraform init \
  -backend-config "bucket=${REMOTE_STATE_BUCKET}" \
  -backend-config "key=shared-ses-infra/aws" \
  -backend-config "region=${AWS_DEFAULT_REGION}"
```

Confirm shared-ses-infra does not already own the resources:

```bash
terraform state list
```

Expected: none of these addresses are present:

```text
module.ses_receipt_rule_set.aws_ses_receipt_rule_set.main
module.gtd_inbound_rule.aws_ses_receipt_rule.main
module.music_submission_rule.aws_ses_receipt_rule.main
```

Confirm the pre-import plan shows only the three modeled creates:

```bash
terraform plan -refresh=false -input=false -no-color
```

Expected:

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

Expected create addresses:

```text
module.ses_receipt_rule_set.aws_ses_receipt_rule_set.main
module.gtd_inbound_rule.aws_ses_receipt_rule.main
module.music_submission_rule.aws_ses_receipt_rule.main
```

Confirm live SES still matches the model:

```bash
aws ses describe-active-receipt-rule-set --region ap-southeast-2
```

Expected:

- active rule set is `shared-inbound-mail-rules`
- `gtd-inbound` is enabled, scans mail, uses TLS `Optional`, receives `parse.namasteapp.tech`, writes to `gtd-ses-emails`, then invokes `arn:aws:lambda:ap-southeast-2:352311918919:function:gtd-ses-forwarder` with `Event`
- `music-submission` is enabled, scans mail, uses TLS `Optional`, receives `parse.lushauraltreats.com`, writes to `lush-aural-treats-ses-emails`, then invokes `arn:aws:lambda:ap-southeast-2:352311918919:function:lush-aural-treats-ses-forwarder` with `Event`

## Import Commands

Run from `infrastructure/aws` only after the pre-import checks pass.

Import the rule set first:

```bash
terraform import \
  'module.ses_receipt_rule_set.aws_ses_receipt_rule_set.main' \
  'shared-inbound-mail-rules'
```

Import the first rule:

```bash
terraform import \
  'module.gtd_inbound_rule.aws_ses_receipt_rule.main' \
  'shared-inbound-mail-rules:gtd-inbound'
```

Import the second rule:

```bash
terraform import \
  'module.music_submission_rule.aws_ses_receipt_rule.main' \
  'shared-inbound-mail-rules:music-submission'
```

Do not import `aws_ses_active_receipt_rule_set` in this phase.

## Post-Import Checks

Confirm the three imported addresses are now in state:

```bash
terraform state list
```

Expected addresses:

```text
module.ses_receipt_rule_set.aws_ses_receipt_rule_set.main
module.gtd_inbound_rule.aws_ses_receipt_rule.main
module.music_submission_rule.aws_ses_receipt_rule.main
```

Confirm Terraform sees no changes:

```bash
terraform plan -input=false -no-color
```

Expected:

```text
Plan: 0 to add, 0 to change, 0 to destroy.
```

Confirm the active rule set was not changed:

```bash
aws ses describe-active-receipt-rule-set --region ap-southeast-2
```

Expected:

- active rule set remains `shared-inbound-mail-rules`
- both rules remain enabled
- recipients are unchanged
- action order remains S3 first, Lambda second
- S3 buckets and Lambda ARNs are unchanged
- Lambda invocation type remains `Event`
- scan remains enabled
- TLS remains `Optional`

## Active Rule Set Drift Risk

Importing `aws_ses_receipt_rule_set` and `aws_ses_receipt_rule` does not import or manage `aws_ses_active_receipt_rule_set`.

Because `activate = false`, the module does not create an `aws_ses_active_receipt_rule_set` resource. That is intentional for this phase and avoids any Terraform-managed activation or switch.

The tradeoff is that Terraform will not detect or correct drift if another stack changes the active receipt rule set. Keep the `aws ses describe-active-receipt-rule-set --region ap-southeast-2` check as a required pre- and post-import guard until a later, explicit activation ownership step is planned.

## Stop Conditions

Stop before import if:

- Terraform is not initialized against the intended shared-ses-infra backend
- `terraform state list` already contains any of the target addresses
- `terraform plan -refresh=false` shows anything other than the three modeled SES creates
- live SES active rule set is not `shared-inbound-mail-rules`
- either live rule is missing, disabled, has different recipients, or has different actions
- live rule action order is not S3 first and Lambda second
- any command implies creation, deletion, activation, or replacement of SES resources
- any change would touch Namaste, Lush, DNS, S3, Lambda, IAM, or parser/product behavior

Stop after import if:

- `terraform plan` shows any add, change, destroy, or activation action
- `aws ses describe-active-receipt-rule-set` no longer matches the pre-import output
- any imported address is missing from state
- any unexpected local state file appears because the backend was not configured
