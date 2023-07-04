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
variable "ServerIDHeaderValue" {
  description = "Consul cluster endpoint.  Ex: mycluster.private.consul.ca8d89d06b07.aws.hashicorp.cloud"
  type        = string
}
variable "BoundIAMPrincipalARNs" {
  description = "IAM instance profile ARN used by Consul IAM Auth"
  type        = list(any)
  default     = ["arn:aws:iam::729755634065:instance-profile/consul_profile"]
}