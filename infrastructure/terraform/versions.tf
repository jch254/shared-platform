terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "jch254-terraform-remote-state"
    key    = "shared-platform"
    region = "ap-southeast-4"
  }
}
