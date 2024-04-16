terraform {
  cloud {
    organization = "learn-tf-sj28"
    workspaces {
      name = "ec2-private-subnet"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}
