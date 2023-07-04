variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnets to associate with the VPC attachment"
  type        = list(string)
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