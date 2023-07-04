/*
Set the following Env variables to connect to HCP
  variable "HCP_CLIENT_SECRET"
  variable "HCP_CLIENT_ID"
*/

variable "prefix" {
  description = "unique prefix for resources"
  type        = string
  default     = "presto"
}


variable "region" {
  description = "The region of the HCP HVN and Consul cluster."
  type        = string
  default     = "us-west-2"
}

variable "role_name" {
  description = "The region of the HCP HVN and Consul cluster."
  type        = string
  default     = "consul-role"
}