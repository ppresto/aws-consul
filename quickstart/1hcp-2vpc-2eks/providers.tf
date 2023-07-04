
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
}

# Required to setup policies/tokens for EC2 services
provider "consul" {
  alias      = "usw2"
  address    = module.hcp_consul_usw2[local.hvn_list_usw2[0]].consul_public_endpoint_url
  datacenter = module.hcp_consul_usw2[local.hvn_list_usw2[0]].datacenter
  token      = module.hcp_consul_usw2[local.hvn_list_usw2[0]].consul_root_token_secret_id
}