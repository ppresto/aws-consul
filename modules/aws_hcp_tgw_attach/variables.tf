/*
Set the following Env variables to connect to HCP
  variable "HCP_CLIENT_SECRET"
  variable "HCP_CLIENT_ID"
*/
variable "region" {
  description = "The region of the HCP HVN and Consul cluster."
  type        = string
  default     = "us-west-2"
}

variable "hvn_id" {
  description = "The ID of the HCP HVN."
  type        = string
}
variable "hvn_link" {
  description = "module.hcp_consul.hvn_self_link"
}
variable "hvn_provider_account_id" {
  description = "hcp_hvn.example_hvn.provider_account_id"
}
variable "tgw_resource_association_arn" {
  description = "module.tgw.ec2_transit_gateway_arn"
}
variable "transit_gateway_id" {
  description = "module.tgw.ec2_transit_gateway_id"
}

variable "ram_resource_share_name" { default = "hcpc-usw2-share" }
variable "transit_gateway_attachment_id" { default = "hcpc-tgw-usw2-attachment" }
variable "hvn_route_id" { default = "hvn-to-tgw-usw2-attachment" }
variable "hvn_route_cidr_list" {
  description = "List of CIDR blocks participating in HCP Consul Shared service"
  type        = list(string)
  default     = ["10.0.0.0/10"]
}