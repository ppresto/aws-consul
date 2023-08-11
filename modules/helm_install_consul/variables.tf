/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

variable "chart_name" {
  type        = string
  default     = "consul"
  description = "Chart name to be installed"
}

variable "chart_repository" {
  type        = string
  default     = "https://helm.releases.hashicorp.com"
  description = "Repository URL where to locate the requested chart"
}

variable "cluster_name" {
  type        = string
  description = "Name of AKS cluster"
}

variable "server_replicas" {
  type        = string
  description = "consul cluster size"
  default     = 1
}

variable "consul_helm_chart_version" {
  type        = string
  description = "Version of Consul helm chart."
  # Changing this version may break the reliability
  # of Consul installation and federation
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  # default = "1.13.3" - Cluster Peering
  default = "0.41.0"
}
variable "consul_helm_chart_template" {
  description = "Select helm chart template."
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  #default     = "0.41.1"
}

variable "consul_client_helm_chart_template" {
  description = "Select helm chart template."
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  default = ""
}

variable "consul_version" {
  type        = string
  description = "Version of Consul Enterprise to install"
  default     = "1.15.2"
}

variable "consul_license" {
  type        = string
  description = "Consul license"
}

variable "consul_type" {
  description = "Server or Client"
  type        = string
  default     = "dataplane"
}
variable "consul_namespace" {
  type        = string
  default     = "consul"
  description = "The namespace to install the release into"
}
variable "consul_partition" {
  type        = string
  default     = "default"
  description = "The partition to install the release into"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create the k8s namespace if it does not yet exist"
}

variable "kubernetes_namespace" {
  type        = string
  default     = "consul"
  description = "The namespace to install the k8s resources into"
}

# variable "primary_datacenter" {
#   type        = bool
#   description = "If true, installs Consul with a primary datacenter configuration. Set to false for secondary datacenters"
#   default = false
# }

# variable "primary_datacenter_name" {
#   description = "Primary datacenter name required by helm chart"
#   default     = "dc1"
# }

# variable "enable_cluster_peering" {
#   description = "Set this variable to true if you want to setup all Consul clusters as primaries that support cluster peering"
#   default     = false
# }
# variable "client" {
#   description = "Set this variable to true to bootstrap aks cluster to consul"
#   default     = false
# }
variable "eks_cluster_endpoint" {
  description = "agents need the consul cluster location"
  default     = ""
}
variable "consul_external_servers" {
  description = "agents need the consul cluster location"
}
variable "hcp_consul_config_file" {
  description = "HCP Consul client config file"
}
variable "hcp_consul_ca_file" {
  description = "HCP Consul CA file"
}
variable "hcp_consul_root_token_secret_id" {
  description = "HCP Consul root token for initial configuration"
}


variable "release_name" {
  type        = string
  default     = "consul-release"
  description = "The helm release name"
}
variable "datacenter" {
  type        = string
  default     = "consul datacenter"
  description = "dc1"
}
variable "node_selector" {
  type        = string
  description = "Set a nodeSelector to a node lable to force the deployment to specific nodes"
  default     = ""
}