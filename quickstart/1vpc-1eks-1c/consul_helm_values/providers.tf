provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

terraform {
  required_version = ">= 1.3.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.17.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.53.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.17.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.8.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}