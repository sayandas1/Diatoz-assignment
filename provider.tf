terraform {
  cloud {
    organization = "tf-ecs"
    workspaces {
      name = "demo-ecs"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
}