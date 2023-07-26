
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
provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
  #ignore EKS subnet tag updates done to VPC.
  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
  }
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
  }
}

# Required to setup policies/tokens for EC2 services
# provider "consul" {
#   alias      = "usw2"
#   address    = "http://k8s-consul-consului-52b687657e-77eaa847178b90c9.elb.us-west-2.amazonaws.com"
#   datacenter = "dc1"
#   token      = "ea79eb04-ecb4-a6ff-73a5-df8620bc5a88"
# }