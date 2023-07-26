data "aws_region" "usw2" {
  provider = aws.usw2
}
data "aws_availability_zones" "usw2" {
  provider = aws.usw2
  state    = "available"
}

data "aws_caller_identity" "usw2" {
  provider = aws.usw2
}

locals {
  # US-WEST-2 DC Configuration
  usw2 = {
    "usw2-app1" = {
      "vpc" = {
        "name" : "${var.prefix}-usw2-app1"
        "cidr" : "10.16.0.0/20",
        "private_subnets" : ["10.16.1.0/24", "10.16.2.0/24", "10.16.3.0/24", "10.16.4.0/24"],
        "public_subnets" : ["10.16.11.0/24", "10.16.12.0/24", "10.16.13.0/24"],
        "routable_cidr_blocks" : ["10.16.0.0/20"]
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-usw2-app1",
        "cluster_version" : var.eks_cluster_version,
        "ec2_ssh_key" : var.ec2_key_pair_name,
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true,
        "eks_min_size" : 3,
        "eks_max_size" : 3,
        "eks_desired_size" : 3             # used for pool size and consul replicas size
        "eks_instance_type" : "m5.2xlarge" #"m6i.large", "c6i.large"
        #"service_ipv4_cidr" : "10.17.16.0/24" #Can't overlap with VPC CIDR
        "consul_helm_chart_template" : "values-server.yaml"
        "consul_datacenter" : "dc1"
        "consul_type" : "server"
      }
    }
  }
  # HCP Runtime
  # consul_config_file_json_usw2 = jsondecode(base64decode(module.hcp_consul_usw2[local.hvn_list_usw2[0]].consul_config_file))
  # consul_gossip_key_usw2       = local.consul_config_file_json_usw2.encrypt
  # consul_retry_join_usw2       = local.consul_config_file_json_usw2.retry_join

  # Resource location lists used to build other data structures
  tgw_list_usw2 = flatten([for env, values in local.usw2 : ["${env}"] if contains(keys(values), "tgw")])
  hvn_list_usw2 = flatten([for env, values in local.usw2 : ["${env}"] if contains(keys(values), "hcp-consul")])
  vpc_list_usw2 = flatten([for env, values in local.usw2 : ["${env}"] if contains(keys(values), "vpc")])

  # Use HVN cidr block to create routes from VPC to HCP Consul.  Convert to map to support for_each
  hvn_cidrs_list_usw2 = [for env, values in local.usw2 : {
    "hvn" = {
      "cidr" = values.hcp-consul.cidr_block
      "env"  = env
    }
    } if contains(keys(values), "hcp-consul")
  ]
  hvn_cidrs_map_usw2 = { for item in local.hvn_cidrs_list_usw2 : keys(item)[0] => values(item)[0] }

  # create list of objects with routable_cidr_blocks for each vpc and tgw combo. Convert to map.
  vpc_tgw_cidr_usw2 = flatten([for env, values in local.usw2 :
    flatten([for tgw-key, tgw-val in local.tgw_list_usw2 :
      flatten([for cidr in values.vpc.routable_cidr_blocks : {
        "${env}-${tgw-val}-${cidr}" = {
          "tgw_env" = tgw-val
          "vpc_env" = env
          "cidr"    = cidr
        }
        }
      ])
    ])
  ])
  vpc_tgw_cidr_map_usw2 = { for item in local.vpc_tgw_cidr_usw2 : keys(item)[0] => values(item)[0] }

  # create list of routable_cidr_blocks for each internal VPC to add, convert to map
  vpc_routes_usw2 = flatten([for env, values in local.usw2 :
    flatten([for id, routes in local.vpc_tgw_cidr_map_usw2 : {
      "${env}-${routes.tgw_env}-${routes.cidr}" = {
        "tgw_env"    = routes.tgw_env
        "vpc_env"    = routes.vpc_env
        "target_vpc" = env
        "cidr"       = routes.cidr
      }
      } if routes.vpc_env != env
    ])
  ])
  vpc_routes_map_usw2 = { for item in local.vpc_routes_usw2 : keys(item)[0] => values(item)[0] }
  # create list of hvn and tgw to attach them.  Convert to map.
  hvn_tgw_attachments_usw2 = flatten([for hvn in local.hvn_list_usw2 :
    flatten([for tgw in local.tgw_list_usw2 : {
      "hvn-${hvn}-tgw-${tgw}" = {
        "tgw_env" = tgw
        "hvn_env" = hvn
      }
      }
    ])
  ])
  hvn_tgw_attachments_map_usw2 = { for item in local.hvn_tgw_attachments_usw2 : keys(item)[0] => values(item)[0] }

  # Create list of tgw and vpc for attachments.  Convert to map.
  tgw_vpc_attachments_usw2 = flatten([for vpc in local.vpc_list_usw2 :
    flatten([for tgw in local.tgw_list_usw2 :
      {
        "vpc-${vpc}-tgw-${tgw}" = {
          "tgw_env" = tgw
          "vpc_env" = vpc
        }
      }
    ])
  ])
  tgw_vpc_attachments_map_usw2 = { for item in local.tgw_vpc_attachments_usw2 : keys(item)[0] => values(item)[0] }

  # Concat all VPC/Env private_cidr_block lists into one distinct list of routes to add TGW.
  all_routable_cidr_blocks_usw2 = distinct(flatten([for env, values in local.usw2 :
    values.vpc.routable_cidr_blocks
  ]))

  # Create EC2 Resource map per Proj/Env
  ec2_location_usw2 = flatten([for env, values in local.usw2 : {
    "${env}" = values.ec2
    } if contains(keys(values), "ec2")
  ])
  ec2_location_map_usw2 = { for item in local.ec2_location_usw2 : keys(item)[0] => values(item)[0] }
  # Flatten map by EC2 instance and inject Proj/Env.  For_each loop can now build every instance
  ec2_usw2 = flatten([for env, values in local.ec2_location_map_usw2 :
    flatten([for ec2, attr in values : {
      "${env}-${ec2}" = {
        "ec2_ssh_key"                 = attr.ec2_ssh_key
        "target_subnets"              = attr.target_subnets
        "vpc_env"                     = env
        "hostname"                    = ec2
        "associate_public_ip_address" = attr.associate_public_ip_address
        "service"                     = try(attr.service, "default")
        "create_consul_policy"        = try(attr.create_consul_policy, false)
      }
    }])
  ])
  ec2_map_usw2 = { for item in local.ec2_usw2 : keys(item)[0] => values(item)[0] }

  ec2_service_list_usw2 = distinct([for values in local.ec2_map_usw2 : "${values.service}"])

}

# Create usw2 VPCs defined in local.usw2
module "vpc-usw2" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  providers = {
    aws = aws.usw2
  }
  source                   = "terraform-aws-modules/vpc/aws"
  version                  = "~> 3.0"
  for_each                 = local.usw2
  name                     = try(local.usw2[each.key].vpc.name, "${var.prefix}-${each.key}-vpc")
  cidr                     = local.usw2[each.key].vpc.cidr
  azs                      = [data.aws_availability_zones.usw2.names[0], data.aws_availability_zones.usw2.names[1]]
  private_subnets          = local.usw2[each.key].vpc.private_subnets
  public_subnets           = local.usw2[each.key].vpc.public_subnets
  enable_nat_gateway       = true
  single_nat_gateway       = true
  enable_dns_hostnames     = true
  enable_ipv6              = false
  default_route_table_name = "${var.prefix}-${each.key}-vpc1"

  # Cloudwatch log group and IAM role will be created
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  flow_log_max_aggregation_interval         = 60
  flow_log_cloudwatch_log_group_name_prefix = "/aws/${local.usw2[each.key].vpc.name}"
  flow_log_cloudwatch_log_group_name_suffix = "flow"

  tags = {
    Terraform  = "true"
    Owner      = "${var.prefix}"
    transit_gw = "true"
  }
  private_subnet_tags = {
    Tier                                                                              = "Private"
    "kubernetes.io/role/internal-elb"                                                 = 1
    "kubernetes.io/cluster/${try(local.usw2[each.key].eks.cluster_name, var.prefix)}" = "shared"
  }
  public_subnet_tags = {
    Tier                                                                              = "Public"
    "kubernetes.io/role/elb"                                                          = 1
    "kubernetes.io/cluster/${try(local.usw2[each.key].eks.cluster_name, var.prefix)}" = "shared"
  }
  default_route_table_tags = {
    Name = "${var.prefix}-vpc1-default"
  }
  private_route_table_tags = {
    Name = "${var.prefix}-vpc1-private"
  }
  public_route_table_tags = {
    Name = "${var.prefix}-vpc1-public"
  }
}

# Create EKS cluster per VPC defined in local.usw2
# NOTE: The selfmanaged module doesn't support for_each. Its required to config k8s provider.
# selfmanaged nodes need to configure the aws_auth config map to access K8s cluster.
module "eks-usw2" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  providers = {
    aws = aws.usw2
  }
  source                          = "../../modules/aws_eks_cluster_selfmanaged"
  cluster_name                    = try(local.usw2["usw2-app1"].eks.cluster_name, local.name)
  cluster_version                 = try(local.usw2["usw2-app1"].eks.eks_cluster_version, var.eks_cluster_version)
  cluster_endpoint_private_access = try(local.usw2["usw2-app1"].eks.cluster_endpoint_private_access, true)
  cluster_endpoint_public_access  = try(local.usw2["usw2-app1"].eks.cluster_endpoint_public_access, true)
  cluster_service_ipv4_cidr       = try(local.usw2["usw2-app1"].eks.service_ipv4_cidr, "172.20.0.0/16")
  min_size                        = try(local.usw2["usw2-app1"].eks.eks_min_size, var.eks_min_size)
  max_size                        = try(local.usw2["usw2-app1"].eks.eks_max_size, var.eks_max_size)
  desired_size                    = try(local.usw2["usw2-app1"].eks.eks_desired_size, var.eks_desired_size)
  instance_type                   = try(local.usw2["usw2-app1"].eks.eks_instance_type, null)
  vpc_id                          = module.vpc-usw2["usw2-app1"].vpc_id
  subnet_ids                      = module.vpc-usw2["usw2-app1"].private_subnets
  all_routable_cidrs              = local.all_routable_cidr_blocks_usw2
  hcp_cidr                        = []
}

resource "local_file" "usw2" {
  for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }
  content  = templatefile("${path.module}/../templates/consul_helm_client.tmpl",
    {
    region_shortname            = "usw2"
    cluster_name                = try(local.usw2[each.key].eks.cluster_name, local.name)
    server_replicas             = try(local.usw2["usw2-app1"].eks.eks_desired_size, var.eks_desired_size)
    datacenter                  = try(local.usw2[each.key].eks.consul_datacenter, "dc1")
    consul_type                 = try(local.usw2[each.key].eks.consul_type, "client")
    release_name                = "consul-${each.key}"
    consul_external_servers     = "NO_HCP_SERVERS"
    eks_cluster_endpoint        = module.eks-usw2.cluster_endpoint
    consul_version              = var.consul_version
    consul_helm_chart_version   = var.consul_helm_chart_version
    consul_helm_chart_template  = try(local.usw2[each.key].eks.consul_helm_chart_template, var.consul_helm_chart_template)
    consul_chart_name           = "consul"
    consul_ca_file              = ""
    consul_config_file          = ""
    consul_root_token_secret_id = ""
    consul_type                 = "dataplane"
    partition                   = try(local.usw2[each.key].eks.consul_partition, var.consul_partition)
    node_selector               = "nodegroup: consul" #K8s node label to target deployment too.
    })
  filename = "${path.module}/consul_helm_values/auto-${local.usw2[each.key].eks.cluster_name}.tf"
}

output "usw2_regions" {
  value = { for k, v in local.usw2 : k => data.aws_region.usw2.name }
}
output "usw2_projects" { # Used by ./scripts/kubectl_connect_eks.sh to loop through Proj/Env and Auth to EKS clusters
  value = [for proj in sort(keys(local.usw2)) : proj]
}
# VPC
output "usw2_vpc_ids" {
  value = { for env in sort(keys(local.usw2)) : env => module.vpc-usw2[env].vpc_id }
}
### EKS
output "usw2_eks_cluster_endpoints" {
  description = "Endpoint for your Kubernetes API server"
  value       = { for k, v in local.usw2 : k => module.eks-usw2.cluster_endpoint if contains(keys(v), "eks") }
}
output "usw2_eks_cluster_names" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready"
  value       = { for k, v in local.usw2 : k => local.usw2[k].eks.cluster_name if contains(keys(v), "eks") }
}