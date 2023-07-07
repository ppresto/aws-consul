variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnets to associate with the VPC attachment"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
  default     = "mycluster"
}
variable "cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.24"
}

variable "cluster_endpoint_private_access" {
  description = "EKS private endpoint"
  type        = bool
  default     = true
}
variable "cluster_endpoint_public_access" {
  description = "EKS public endpoint"
  type        = bool
  default     = true
}

variable "cluster_service_ipv4_cidr" {
  description = "EKS ipv4 CIDR"
  type        = string
  default     = "172.20.0.0/16"
}
variable "min_size" {
  description = "EKS min size"
  type        = number
  default     = 1
}
variable "max_size" {
  description = "EKS max size"
  type        = number
  default     = 3
}
variable "desired_size" {
  description = "EKS max size"
  type        = number
  default     = 3
}
variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.medium"
}
variable "all_routable_cidrs" {
  description = "Allow other Internally routable CIDRs ingress access to cluster"
  type        = list(string)
  default     = []
}
variable "hcp_cidr" {
  description = "Allow HCP CIDR access to cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  #default     = []
}