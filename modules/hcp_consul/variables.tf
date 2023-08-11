/*
Set the following Env variables to connect to HCP
  variable "HCP_CLIENT_SECRET"
  variable "HCP_CLIENT_ID"
*/
variable "cloud_provider" {
  description = "The cloud provider of the HCP HVN and Consul cluster."
  type        = string
  default     = "aws"
}

variable "region" {
  description = "The region of the HCP HVN and Consul cluster."
  type        = string
  default     = "us-west-2"
}

variable "hvn_id" {
  description = "The ID of the HCP HVN."
  type        = string
  default     = "learn-hvn"
}
# HCP Consul Virtual Network CIDR
variable "cidr_block" {
  description = "VPC CIDR Block Range"
  type        = string
  default     = "172.25.16.0/20"
}

variable "cluster_id" {
  description = "The ID of the HCP Consul cluster."
  type        = string
  default     = "learn-hcp-consul"
}
variable "min_consul_version" {
  description = "Minimum version of HCP Consul"
  type        = string
  default     = "1.16.0"
}
variable "tier" {
  description = "Cluster Tier"
  type        = string
  default     = "development"
}
variable "public_endpoint" {
  description = "Make HCP Consul URL Publically available"
  type        = bool
  default     = false
}