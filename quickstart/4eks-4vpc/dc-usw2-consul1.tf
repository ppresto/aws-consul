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
    "consul1" = {
      "vpc" = {
        "name" : "${var.prefix}-usw2-consul1"
        "cidr" : "10.17.0.0/20",
        "private_subnets" : ["10.17.1.0/24", "10.17.2.0/24", "10.17.3.0/24", "10.17.4.0/24"],
        "public_subnets" : ["10.17.11.0/24", "10.17.12.0/24", "10.17.13.0/24"],
        "routable_cidr_blocks" : ["10.17.0.0/20"]
      }
      "tgw" = { #Only 1 TGW needed per region/data center.  Other VPC's can attach to it.
        "name" : "${var.prefix}-usw2-shared-tgw",
        "enable_auto_accept_shared_attachments" : true,
        "ram_allow_external_principals" : true,
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-usw2-consul1",
        "cluster_version" : var.eks_cluster_version,
        "ec2_ssh_key" : var.ec2_key_pair_name,
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true,
        "eks_min_size" : 1,
        "eks_max_size" : 3,
        "eks_desired_size" : 1           # used for pool size and consul replicas size
        "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
        #"service_ipv4_cidr" : "10.17.16.0/24" #Can't overlap with VPC CIDR
        "consul_helm_chart_template" : "values-server.yaml"
        "consul_datacenter" : "dc1"
        "consul_type" : "server"
      }
    }
    "consul2" = {
      "vpc" = {
        "name" : "${var.prefix}-usw2-consul2"
        "cidr" : "10.18.0.0/20",
        "private_subnets" : ["10.18.1.0/24", "10.18.2.0/24", "10.18.3.0/24", "10.18.4.0/24"],
        "public_subnets" : ["10.18.11.0/24", "10.18.12.0/24", "10.18.13.0/24"],
        "routable_cidr_blocks" : ["10.18.0.0/20"]
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-usw2-consul2",
        "cluster_version" : var.eks_cluster_version,
        "ec2_ssh_key" : var.ec2_key_pair_name,
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true,
        "eks_min_size" : 1,
        "eks_max_size" : 3,
        "eks_desired_size" : 1           # used for pool size and consul replicas size
        "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
        #"service_ipv4_cidr" : "10.17.16.0/24" #Can't overlap with VPC CIDR
        "consul_helm_chart_template" : "values-server.yaml"
        "consul_datacenter" : "dc2"
        "consul_type" : "server"
      }
    }
    "app1" = {
      "vpc" = {
        "name" : "${var.prefix}-usw2-app1"
        "cidr" : "10.50.0.0/20",
        "private_subnets" : ["10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24", "10.50.4.0/24"],
        "public_subnets" : ["10.50.11.0/24", "10.50.12.0/24", "10.50.13.0/24"],
        "routable_cidr_blocks" : ["10.50.0.0/20"]
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-usw2-app1",
        "cluster_version" : var.eks_cluster_version,
        "ec2_ssh_key" : var.ec2_key_pair_name,
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true,
        "eks_min_size" : 1,
        "eks_max_size" : 3,
        "eks_desired_size" : 1           # used for pool size and consul replicas size
        "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
        #"service_ipv4_cidr" : "10.17.16.0/24" #Can't overlap with VPC CIDR
        "consul_helm_chart_template" : "values-dataplane.yaml"
        "consul_datacenter" : "dc1"
        "consul_type" : "client"
        "consul_partition" : "app1"
      }
    }
    "app2" = {
      "vpc" = {
        "name" : "${var.prefix}-usw2-app2"
        "cidr" : "10.60.0.0/20",
        "private_subnets" : ["10.60.1.0/24", "10.60.2.0/24", "10.60.3.0/24", "10.60.4.0/24"],
        "public_subnets" : ["10.60.11.0/24", "10.60.12.0/24", "10.60.13.0/24"],
        "routable_cidr_blocks" : ["10.60.0.0/20"]
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-usw2-app2",
        "cluster_version" : var.eks_cluster_version,
        "ec2_ssh_key" : var.ec2_key_pair_name,
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true,
        "eks_min_size" : 1,
        "eks_max_size" : 3,
        "eks_desired_size" : 1           # used for pool size and consul replicas size
        "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
        #"service_ipv4_cidr" : "10.17.16.0/24" #Can't overlap with VPC CIDR
        "consul_helm_chart_template" : "values-dataplane.yaml"
        "consul_datacenter" : "dc2"
        "consul_type" : "client"
        "consul_partition" : "app2"
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

module "tgw-usw2" {
  # TransitGateway: https://registry.terraform.io/modules/terraform-aws-modules/transit-gateway/aws/latest
  providers = {
    aws = aws.usw2
  }
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "2.8.2"

  for_each                              = { for k, v in local.usw2 : k => v if contains(keys(v), "tgw") }
  description                           = "${var.prefix}-${each.key}-tgw - AWS Transit Gateway"
  name                                  = try(local.usw2[each.key].tgw.name, "${var.prefix}-${each.key}-tgw")
  enable_auto_accept_shared_attachments = try(local.usw2[each.key].tgw.enable_auto_accept_shared_attachments, true) # When "true" there is no need for RAM resources if using multiple AWS accounts
  ram_allow_external_principals         = try(local.usw2[each.key].tgw.ram_allow_external_principals, true)
  amazon_side_asn                       = 64532
  tgw_default_route_table_tags = {
    name = "${var.prefix}-${each.key}-tgw-default_rt"
  }
  tags = {
    project = "${var.prefix}-${each.key}-tgw"
  }
}

# Attach 1+ Transit Gateways to each VPC and create routes for the private subnets
module "tgw_vpc_attach_usw2" {
  source = "../../modules/aws_tgw_vpc_attach"
  providers = {
    aws = aws.usw2
  }
  #for_each = local.vpc_tgw_locations_map_usw2
  for_each           = local.tgw_vpc_attachments_map_usw2
  subnet_ids         = module.vpc-usw2[each.value.vpc_env].private_subnets
  transit_gateway_id = module.tgw-usw2[each.value.tgw_env].ec2_transit_gateway_id
  vpc_id             = module.vpc-usw2[each.value.vpc_env].vpc_id
  tags = {
    project = "${var.prefix}-${each.key}-tgw"
  }
}
# Create additional private routes between VPCs so they can see each other.
module "route_add_usw2" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.usw2
  }
  for_each               = local.vpc_routes_map_usw2
  route_table_id         = module.vpc-usw2[each.value.target_vpc].private_route_table_ids[0]
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.tgw-usw2[each.value.tgw_env].ec2_transit_gateway_id
  depends_on             = [module.tgw_vpc_attach_usw2]
}
#Add private routes to public route table to support SSH from bastion host.
module "route_public_add_usw2" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.usw2
  }
  for_each               = local.vpc_routes_map_usw2
  route_table_id         = module.vpc-usw2[each.value.target_vpc].public_route_table_ids[0]
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.tgw-usw2[each.value.tgw_env].ec2_transit_gateway_id
  depends_on             = [module.tgw_vpc_attach_usw2]
}
module "eks-usw2" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  providers = {
    aws = aws.usw2
  }
  source                          = "../../modules/aws_eks_cluster"
  for_each                        = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }
  cluster_name                    = try(local.usw2[each.key].eks.cluster_name, local.name)
  cluster_version                 = try(local.usw2[each.key].eks.eks_cluster_version, var.eks_cluster_version)
  cluster_endpoint_private_access = try(local.usw2[each.key].eks.cluster_endpoint_private_access, true)
  cluster_endpoint_public_access  = try(local.usw2[each.key].eks.cluster_endpoint_public_access, true)
  cluster_service_ipv4_cidr       = try(local.usw2[each.key].eks.service_ipv4_cidr, "172.20.0.0/16")
  min_size                        = try(local.usw2[each.key].eks.eks_min_size, var.eks_min_size)
  max_size                        = try(local.usw2[each.key].eks.eks_max_size, var.eks_max_size)
  desired_size                    = try(local.usw2[each.key].eks.eks_desired_size, var.eks_desired_size)
  instance_type                   = try(local.usw2[each.key].eks.eks_instance_type, null)
  vpc_id                          = module.vpc-usw2[each.key].vpc_id
  subnet_ids                      = module.vpc-usw2[each.key].private_subnets
  all_routable_cidrs              = local.all_routable_cidr_blocks_usw2
  #hcp_cidr                        = local.all_routable_cidr_blocks_usw2
}

data "template_file" "eks_clients_usw2" {
  for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }

  template = file("${path.module}/../templates/consul_helm_client.tmpl")
  vars = {
    region_shortname            = "usw2"
    cluster_name                = try(local.usw2[each.key].eks.cluster_name, local.name)
    server_replicas             = try(local.usw2[each.key].eks.eks_desired_size, var.eks_desired_size)
    datacenter                  = try(local.usw2[each.key].eks.consul_datacenter, "dc1")
    consul_type                 = try(local.usw2[each.key].eks.consul_type, "client")
    release_name                = "consul-${each.key}"
    consul_external_servers     = "NO_HCP_SERVERS"
    eks_cluster_endpoint        = module.eks-usw2[each.key].cluster_endpoint
    consul_version              = var.consul_version
    consul_helm_chart_version   = var.consul_helm_chart_version
    consul_helm_chart_template  = try(local.usw2[each.key].eks.consul_helm_chart_template, var.consul_helm_chart_template)
    consul_chart_name           = "consul"
    consul_ca_file              = ""
    consul_config_file          = ""
    consul_root_token_secret_id = ""
    partition                   = try(local.usw2[each.key].eks.consul_partition, var.consul_partition)
    node_selector               = "" #K8s node label to target deployment too.
  }
}

resource "local_file" "usw2" {
  for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }
  content  = data.template_file.eks_clients_usw2[each.key].rendered
  filename = "${path.module}/consul_helm_values/auto-${local.usw2[each.key].eks.cluster_name}.tf"
}

resource "local_file" "test" {
  for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }
  content  = templatefile("${path.module}/../templates/consul_helm_client.tmpl",
    {
      region_shortname            = "usw2"
      cluster_name                = try(local.usw2[each.key].eks.cluster_name, local.name)
      server_replicas             = try(local.usw2[each.key].eks.eks_desired_size, var.eks_desired_size)
      datacenter                  = try(local.usw2[each.key].eks.consul_datacenter, "dc1")
      consul_type                 = try(local.usw2[each.key].eks.consul_type, "client")
      release_name                = "consul-${each.key}"
      consul_external_servers     = "NO_HCP_SERVERS"
      eks_cluster_endpoint        = module.eks-usw2[each.key].cluster_endpoint
      consul_version              = var.consul_version
      consul_helm_chart_version   = var.consul_helm_chart_version
      consul_helm_chart_template  = try(local.usw2[each.key].eks.consul_helm_chart_template, var.consul_helm_chart_template)
      consul_chart_name           = "consul"
      consul_ca_file              = ""
      consul_config_file          = ""
      consul_root_token_secret_id = ""
      partition                   = try(local.usw2[each.key].eks.consul_partition, var.consul_partition)
      node_selector               = "" #K8s node label to target deployment too.
    })
  filename = "${path.module}/consul_helm_values/2auto-${local.usw2[each.key].eks.cluster_name}.tf"
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
  value       = { for k, v in local.usw2 : k => module.eks-usw2[k].cluster_endpoint if contains(keys(v), "eks") }
}
output "usw2_eks_cluster_names" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready"
  value       = { for k, v in local.usw2 : k => local.usw2[k].eks.cluster_name if contains(keys(v), "eks") }
}