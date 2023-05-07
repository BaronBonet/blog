terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "ericcbonet-blog-terraform"
    key    = "state/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  alias  = "eu-central-1"
  region = var.region
}
