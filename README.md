# shared-platform

Owner repo for shared account-level platform infrastructure.

This repository owns shared SES inbound routing for Namaste and Lush, plus the shared CodeBuild notification infrastructure used by app repos. Product parser behavior, forwarder implementation, authentication, allowlists, task or album creation, confirmation emails, retries, outbound providers, and other app logic remain app-local.

## Why This Exists

Amazon SES has one active receipt rule set per AWS account and region. Namaste and Lush both receive inbound email in `ap-southeast-2`, so a product-local active rule set can accidentally remove the other app's route.

This repo is the shared platform boundary for:

- `parse.namasteapp.tech`
- `parse.lushauraltreats.com`
- future `parse.<domain>` inbound domains
- shared CodeBuild success/failure notifications

## Structure

```text
infrastructure/
  deploy-infrastructure.bash
  terraform/
    main.tf                 # AWS shared-platform root
    variables.tf
    outputs.tf
    versions.tf
    moved.tf
    environments/prod/
    cloudflare/             # scaffold-only DNS model for future SES DNS ownership
```

`infrastructure/terraform` is the runnable AWS root. It uses the S3 state key `shared-platform`.

`infrastructure/terraform/cloudflare` is intentionally scaffold-only for now. It models future parse-domain DNS ownership, but does not currently deploy live Cloudflare records.

## Current Model

The AWS root owns the live `shared-inbound-mail-rules` receipt rule set and these SES receipt rules:

- `gtd-inbound` for `parse.namasteapp.tech`, storing raw mail in `gtd-ses-emails` and invoking `gtd-ses-forwarder`
- `music-submission` for `parse.lushauraltreats.com`, storing raw mail in `lush-aural-treats-ses-emails` and invoking `lush-aural-treats-ses-forwarder`

Active receipt rule set activation is intentionally unmanaged by Terraform for now. The active selector currently points at `shared-inbound-mail-rules`; adopting `aws_ses_active_receipt_rule_set` into this repo should be a separate reviewed change.

The AWS root also deploys shared CodeBuild notification infrastructure with `terraform-modules`:

- SNS topic and email subscription for CodeBuild notifications
- Lambda formatter for build success/failure events
- app-owned EventBridge subscription for the `shared-platform` CodeBuild project
- outputs for app repos to target with their own EventBridge rules

App repos opt in by creating their own EventBridge rule and Lambda permission with `build-notifier-project-subscription`. `reference-architecture` is the first app wired this way. Namaste and Lush remain on their local notifiers until their own follow-up migration passes.

## Build Deploys

The AWS root creates a `shared-platform` CodeBuild project in `aws_region`. It runs [buildspec.yml](buildspec.yml), which calls [infrastructure/deploy-infrastructure.bash](infrastructure/deploy-infrastructure.bash) and applies `infrastructure/terraform`.

Bootstrap is still manual once:

1. Review `infrastructure/terraform/environments/prod/terraform.tfvars`.
2. Run a local/one-off `terraform plan` and `terraform apply` from `infrastructure/terraform`.
3. Confirm the SNS email subscription.
4. Let the `shared-platform` CodeBuild webhook handle later AWS-root changes.

## Ownership Boundary

shared-platform owns:

- `aws_ses_receipt_rule_set` `shared-inbound-mail-rules`
- `aws_ses_receipt_rule` `gtd-inbound`
- `aws_ses_receipt_rule` `music-submission`
- the shared `shared-platform-build-notifications` SNS topic and formatter Lambda for CodeBuild project notifications
- the `shared-platform` CodeBuild project that deploys this Terraform root
- the `shared-platform` CodeBuild EventBridge notification subscription

Namaste and Lush product stacks must not apply product-local receipt rule or receipt rule set changes that conflict with `shared-inbound-mail-rules`. Do not reactivate product-only rule sets such as `gtd-rules` or `lush-aural-treats-rules` while this shared account routes both apps through `shared-inbound-mail-rules`.

Still app-local unless migrated separately:

- parse-domain SES identities and DKIM
- parse-domain Cloudflare verification, DKIM, and MX records
- raw mail buckets and bucket policies
- app-specific forwarder Lambdas
- Lambda permissions for SES invoke
- forwarder IAM roles and policies
- SSM secrets and parser endpoint configuration
- inbound parser auth, allowlists, dedupe, task/submission creation, confirmations, retries, and outbound provider choices

Future migration work:

- decide whether shared-platform should later manage `aws_ses_active_receipt_rule_set`
- migrate Namaste and Lush CodeBuild projects onto app-owned subscriptions targeting the shared build notifier, then remove their product-local notifier resources
- migrate or import parse-domain SES identities/DKIM only after state ownership is planned
- migrate or import parse-domain DNS records only after Cloudflare ownership is planned
- decide whether raw buckets, bucket policies, Lambda permissions, and forwarders remain app-local or move into shared modules
- retire any remaining product-local duplicate receipt rule/rule-set resources only after a reviewed state plan

## Verification

To confirm shared-platform ownership is intact and live SES is healthy:

```bash
cd infrastructure/terraform
terraform init \
  -backend-config "bucket=${REMOTE_STATE_BUCKET:-jch254-terraform-remote-state}" \
  -backend-config "key=${TF_STATE_KEY:-shared-platform}" \
  -backend-config "region=${AWS_DEFAULT_REGION:-ap-southeast-4}"
terraform plan -refresh=false -var-file=environments/prod/terraform.tfvars

aws ses describe-active-receipt-rule-set --region ap-southeast-2
```

Expected live SES result: active rule set `shared-inbound-mail-rules` with enabled rules `gtd-inbound` and `music-submission`, scan enabled, TLS `Optional`, S3 raw mail actions, and Lambda invocation type `Event`.

Optional DNS sanity:

```bash
dig MX parse.namasteapp.tech
dig MX parse.lushauraltreats.com
```

For local scaffold validation only:

```bash
cd infrastructure/terraform
terraform init -backend=false -input=false
terraform validate

cd cloudflare
terraform init -backend=false -input=false
terraform validate
```

## Stop Conditions

Stop before applying if any plan shows:

- creation, replacement, deletion, or activation of an SES receipt rule set before all current routes are represented
- deletion or replacement of `parse.namasteapp.tech` or `parse.lushauraltreats.com` SES identities or DKIM records
- deletion or replacement of existing inbound MX records
- Cloudflare MX/TXT/DKIM records with `proxied = true`
- raw mail bucket replacement or bucket policy changes that have not been tested
- a Lambda permission change that would prevent SES from invoking an app forwarder
- a parser endpoint/auth change, especially Namaste's `x-namaste-email-secret` contract
- any Lush changes outside SES inbound routing
- any product parser or business logic being moved into this repo

Future migrations should model and import/move existing state. They should not recreate live SES or DNS resources.
