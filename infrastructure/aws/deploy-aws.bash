#!/bin/bash -e

echo "Deploying shared-platform AWS infrastructure via Terraform..."

cd "$(dirname "$0")"

terraform init \
  -reconfigure \
  -backend-config "bucket=${REMOTE_STATE_BUCKET}" \
  -backend-config "key=${TF_STATE_KEY:-shared-platform/aws}" \
  -backend-config "region=${AWS_DEFAULT_REGION}" \
  -get=true

VAR_FILE_ARGS=()
if [ -f "environments/prod/terraform.tfvars" ]; then
  VAR_FILE_ARGS=(-var-file=environments/prod/terraform.tfvars)
fi

terraform plan -detailed-exitcode \
  -refresh=false \
  "${VAR_FILE_ARGS[@]}" \
  -out main.tfplan || TF_EXIT=$?

TF_EXIT=${TF_EXIT:-0}

if [ "$TF_EXIT" -eq 0 ]; then
  echo "No shared-platform AWS infrastructure changes — skipping apply"
elif [ "$TF_EXIT" -eq 2 ]; then
  echo "Applying shared-platform AWS infrastructure changes"
  terraform apply -auto-approve main.tfplan
else
  echo "Terraform plan failed"
  exit 1
fi
