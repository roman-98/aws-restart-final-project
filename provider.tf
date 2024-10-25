terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }

  }

backend "remote" {
		hostname = "app.terraform.io"
		organization = "AWS-S3-Website"

		workspaces {
			name = "aws-restart-final-project"
		}
	}
}

provider "aws" {
  region = "eu-west-1"
}

resource "random_string" "suffix" {
  length  = 5
  special = false
}