terraform {
  required_version = ">= 1.3.7"

  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.53.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.17.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
  }
}