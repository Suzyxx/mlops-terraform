terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.97"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
