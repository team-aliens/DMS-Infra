terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "team-dms"

    workspaces {
      name = "dms"
    }
  }
}

provider "aws" {
  region = var.region
}
