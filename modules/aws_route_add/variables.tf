variable "route_table_id" {
  description = "VPC ID"
  type        = string
}

variable "destination_cidr_block" {
  description = "List of subnets to associate with the VPC attachment"
  type        = string
}


variable "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to the TGW VPC attachment"
  type        = map(string)
  default     = {}
}