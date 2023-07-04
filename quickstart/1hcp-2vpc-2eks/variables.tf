locals {
  name = "${var.prefix}-${replace(basename(path.cwd), "_", "-")}"
  #region_shortname = join("", regex("([a-z]{2}).*-([a-z]).*-(\\d+)", data.aws_region.current.name))
  tags = {
    Project    = local.name
    GithubRepo = "aws-consul-ent-eks"
    GithubOrg  = "ppresto"
  }

}

variable "prefix" {
  description = "Unique name to identify all resources. Try using your name."
  type        = string
  default     = "presto"
}

variable "hvn_id" {
  description = "The ID of the HCP HVN."
  type        = string
  default     = "hcp-hvn"
}
# HCP Consul Virtual Network CIDR
variable "hvn_cidr_block" {
  description = "VPC CIDR Block Range"
  type        = string
  default     = "172.25.16.0/20"
}

variable "cluster_id" {
  description = "The ID of the HCP Consul cluster."
  type        = string
  default     = "hcp-consul"
}
variable "min_consul_version" {
  description = "Minimum version of HCP Consul"
  type        = string
  default     = "1.14.6"
}
variable "consul_version" {
  description = "Consul Version - Agents"
  type        = string
  default     = "1.13.6-ent"
}
variable "consul_helm_chart_version" {
  description = "Minimum version of HCP Consul"
  type        = string
  default     = "1.0.2"
}
variable "consul_helm_chart_template" {
  description = "Minimum version of HCP Consul"
  type        = string
  default     = "values-client-agentless-mesh.yaml"
}
variable "consul_partition" {
  description = "Minimum version of HCP Consul"
  type        = string
  default     = "default"
}

variable "cloud_provider" {
  description = "The cloud provider of the HCP HVN and Consul cluster."
  type        = string
  default     = "aws"
}

variable "ec2_key_pair_name" {
  description = "An existing EC2 key pair used to access the bastion server."
  type        = string
  default     = "my-aws-ssh-key-pair"
}

variable "eks_cluster_version" {
  description = "EKS version"
  type        = string
  default     = "1.23"
}
variable "eks_min_size" {
  description = "EKS version"
  type        = string
  default     = 1
}
variable "eks_max_size" {
  description = "EKS version"
  type        = string
  default     = 3
}
variable "eks_desired_size" {
  description = "EKS version"
  type        = string
  default     = 1
}

#HCP routable cidr list
variable "hvn_private_route_cidr_list" {
  description = "List of CIDR blocks participating in HCP Consul Shared service"
  type        = list(string)
  default     = ["10.0.0.0/10"]
}

variable "peer_transit_gateways" {
  description = "EKS version"
  type        = bool
  default     = false
}