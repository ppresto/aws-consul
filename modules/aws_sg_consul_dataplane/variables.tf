
# This prefix will be used in your EKS cluster name.
# Update the ./aws_eks/awscli_eks_connect.sh with your EKS cluster name to connect.
variable "name_prefix" {
  description = "Unique name to identify sg"
  type        = string
  default     = "presto"
}

variable "env" { default = "dev" }
# The EKS cluster will be created in this region.
# Update ./aws_eks/awscli_eks_connect.sh with your region value to connect.
variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

variable "security_group_create" {
  description = "Security Group ID"
  type        = bool
  default     = false
}

variable "security_group_id" {
  description = "Security Group ID"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr_blocks" {
  description = "VPC CIDR Block Range"
  type        = list(any)
}

variable "private_cidr_blocks" {
  description = "VPC CIDR Block Range"
  type        = list(any)
  default     = ["10.0.0.0/10"]
}