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


# variable "region" {
#   description = "The region of the HCP HVN and Consul cluster."
#   type        = string
#   default     = "us-west-2"
# }

# # EC2 Variables
# variable "hostname" {
#   description = "EC2 Instance name."
#   type        = string
#   default     = "ubuntu-0747bdcabd34c712a" # Latest Ubuntu 18.04 LTS (HVM), SSD Volume Type
# }

# variable "ami_id" {
#   description = "AMI ID to be used on all AWS EC2 Instances."
#   type        = string
#   default     = "ami-0747bdcabd34c712a" # Latest Ubuntu 18.04 LTS (HVM), SSD Volume Type
# }

# variable "use_latest_ami" {
#   description = "Whether or not to use the hardcoded ami_id value or to grab the latest value from SSM parameter store."
#   type        = bool
#   default     = true
# }

# variable "ec2_key_pair_name" {
#   description = "An existing EC2 key pair used to access the bastion server."
#   type        = string
#   default     = "ppresto-ptfe-dev-key"
# }

# variable "vpc_id" {
#   description = "VPC id"
#   type        = string
# }
# variable "associate_public_ip_address" {
#   description = "Public IP"
#   type        = bool
#   default     = false
# }

# variable "subnet_id" {
#   description = "VPC subnet"
#   type        = string
# }

# variable "security_group_ids" {
#   description = "SG IDs"
#   type        = list(any)
#   default     = []
# }

# variable "allowed_bastion_cidr_blocks_ipv6" {
#   description = "List of CIDR blocks allowed to access your Bastion.  Defaults to none."
#   type        = list(string)
#   default     = []
# }

# variable "create_consul_policy" {
#   type = bool
#   default = false
# }
variable "consul_service" {
  description = "service name that will be running on ec2"
  default     = "default"
}
# variable "consul_public_endpoint_url" {
#   description = "hcp consul_public_endpoint_url"
#   type        = string
# }
variable "consul_datacenter" {
  description = "hcp consul_datacenter"
  type        = string
}
# variable "consul_ca_file" {
#   description = "hcp consul_ca_file"
#   type        = string
# }
# variable "consul_config_file" {
#   description = "hcp consul_config_file"
#   type        = string
# }
# variable "consul_root_token_secret_id" {
#   description = "hcp consul_root_token_secret_id"
#   type        = string
# }

# # Shared bastion host allowed ingress CIDR
# variable "allowed_bastion_cidr_blocks" {
#   description = "List of CIDR blocks allowed to access your Bastion.  Defaults to Everywhere."
#   type        = list(string)
#   default     = ["0.0.0.0/0"]
# }
