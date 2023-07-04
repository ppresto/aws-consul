data "aws_region" "use1" {
  provider = aws.use1
}
data "aws_availability_zones" "use1" {
  provider = aws.use1
  state    = "available"
}

data "aws_caller_identity" "use1" {
  provider = aws.use1
}

data "aws_iam_policy" "ebscsi-use1" {
  provider = aws.use1
  name     = "AmazonEBSCSIDriverPolicy"
}

locals {
  # US-WEST-2 DC Configuration
  use1 = {
    "use1-shared" = {
      "vpc" = {
        "name" : "${var.prefix}-use1-shared"
        "cidr" : "10.25.0.0/20",
        "private_subnets" : ["10.25.1.0/24", "10.25.2.0/24", "10.25.3.0/24"],
        "public_subnets" : ["10.25.11.0/24", "10.25.12.0/24", "10.25.13.0/24"],
        "routable_cidr_blocks" : ["10.25.0.0/20"],
      }
      "tgw" = { #Only 1 TGW needed per region/data center.  Other VPC's can attach to it.
        "name" : "${var.prefix}-use1-shared-tgw",
        "enable_auto_accept_shared_attachments" : true,
        "ram_allow_external_principals" : true,
      }
      "hcp-consul" = { #Only 1 HVN per region/dc.  
        "hvn_id"                     = "${var.prefix}-hvn-use1"
        "cloud_provider"             = var.cloud_provider
        "cidr_block"                 = "172.25.36.0/23"
        "cluster_id"                 = "${var.prefix}-cluster-use1"
        "tier"                       = "development"
        "min_consul_version"         = var.min_consul_version
        "public_endpoint"            = true
        "hvn_to_hvn_peering_enabled" = true #Define multiple HVN's and Peer directly with HCP (not MGW)
        #"hvn_private_route_cidr_list" : ["10.0.0.0/10"] # Default uses [local.all_routable_cidr_blocks_use1]
      }
      "ec2" = {
        "bastion" = {
          "ec2_ssh_key" : var.ec2_key_pair_name
          "target_subnets" : "public_subnets"
          "associate_public_ip_address" : true
        }
      }
    },
    "use1-app1" = {
      "vpc" = {
        "name" : "${var.prefix}-use1-app1"
        "cidr" : "10.26.0.0/20",
        "private_subnets" : ["10.26.1.0/24", "10.26.2.0/24", "10.26.3.0/24"],
        "public_subnets" : ["10.26.11.0/24", "10.26.12.0/24", "10.26.13.0/24"],
        "routable_cidr_blocks" : ["10.26.0.0/20"]
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-use1-app1",
        "cluster_version" : var.eks_cluster_version,
        "consul_partition" : "app1",
        "ec2_ssh_key" : var.ec2_key_pair_name,
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true,
        #"service_ipv4_cidr" : "10.26.16.0/24"
        "eks_min_size" : 1,
        "eks_max_size" : 2,
        "eks_desired_size" : 1
      }
      "ec2" = {
        "east" = {
          "ec2_ssh_key" : var.ec2_key_pair_name
          "target_subnets" : "private_subnets"
          "associate_public_ip_address" : false
          "service" : "api"
        }
      }
    }
  }
  # HCP Runtime
  # consul_config_file_json_use1 = jsondecode(base64decode(module.hcp_consul_use1[local.hvn_list_use1[0]].consul_config_file))
  # consul_gossip_key_use1       = local.consul_config_file_json_use1.encrypt
  # consul_retry_join_use1       = local.consul_config_file_json_use1.retry_join

  # Resource location lists used to build other data structures
  tgw_list_use1 = flatten([for env, values in local.use1 : ["${env}"] if contains(keys(values), "tgw")])
  hvn_list_use1 = flatten([for env, values in local.use1 : ["${env}"] if contains(keys(values), "hcp-consul")])
  vpc_list_use1 = flatten([for env, values in local.use1 : ["${env}"] if contains(keys(values), "vpc")])

  # Use HVN cidr block to create routes from VPC to HCP Consul.  Convert to map to support for_each
  hvn_cidrs_list_use1 = [for env, values in local.use1 : {
    "hvn" = {
      "cidr" = values.hcp-consul.cidr_block
      "env"  = env
    }
    } if contains(keys(values), "hcp-consul")
  ]
  hvn_cidrs_map_use1 = { for item in local.hvn_cidrs_list_use1 : keys(item)[0] => values(item)[0] }

  # create list of objects with routable_cidr_blocks for each vpc and tgw combo. Convert to map.
  vpc_tgw_cidr_use1 = flatten([for env, values in local.use1 :
    flatten([for tgw-key, tgw-val in local.tgw_list_use1 :
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
  vpc_tgw_cidr_map_use1 = { for item in local.vpc_tgw_cidr_use1 : keys(item)[0] => values(item)[0] }

  # create list of routable_cidr_blocks for each internal VPC to add, convert to map
  vpc_routes_use1 = flatten([for env, values in local.use1 :
    flatten([for id, routes in local.vpc_tgw_cidr_map_use1 : {
      "${env}-${routes.tgw_env}-${routes.cidr}" = {
        "tgw_env"    = routes.tgw_env
        "vpc_env"    = routes.vpc_env
        "target_vpc" = env
        "cidr"       = routes.cidr
      }
      } if routes.vpc_env != env
    ])
  ])
  vpc_routes_map_use1 = { for item in local.vpc_routes_use1 : keys(item)[0] => values(item)[0] }
  # create list of hvn and tgw to attach them.  Convert to map.
  hvn_tgw_attachments_use1 = flatten([for hvn in local.hvn_list_use1 :
    flatten([for tgw in local.tgw_list_use1 : {
      "hvn-${hvn}-tgw-${tgw}" = {
        "tgw_env" = tgw
        "hvn_env" = hvn
      }
      }
    ])
  ])
  hvn_tgw_attachments_map_use1 = { for item in local.hvn_tgw_attachments_use1 : keys(item)[0] => values(item)[0] }

  # Create list of tgw and vpc for attachments.  Convert to map.
  tgw_vpc_attachments_use1 = flatten([for vpc in local.vpc_list_use1 :
    flatten([for tgw in local.tgw_list_use1 :
      {
        "vpc-${vpc}-tgw-${tgw}" = {
          "tgw_env" = tgw
          "vpc_env" = vpc
        }
      }
    ])
  ])
  tgw_vpc_attachments_map_use1 = { for item in local.tgw_vpc_attachments_use1 : keys(item)[0] => values(item)[0] }

  # Concat all VPC/Env private_cidr_block lists into one distinct list of routes to add TGW.
  all_routable_cidr_blocks_use1 = distinct(flatten([for env, values in local.use1 :
    values.vpc.routable_cidr_blocks
  ]))

  # Create EC2 Resource map per Proj/Env
  ec2_location_use1 = flatten([for env, values in local.use1 : {
    "${env}" = values.ec2
    } if contains(keys(values), "ec2")
  ])
  ec2_location_map_use1 = { for item in local.ec2_location_use1 : keys(item)[0] => values(item)[0] }
  # Flatten map by EC2 instance and inject Proj/Env.  For_each loop can now build every instance
  ec2_use1 = flatten([for env, values in local.ec2_location_map_use1 :
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
  ec2_map_use1 = { for item in local.ec2_use1 : keys(item)[0] => values(item)[0] }

  ec2_service_list_use1 = distinct([for values in local.ec2_map_use1 : "${values.service}"])

}

# Create HVN and HCP Consul Cluster
module "hcp_consul_use1" {
  providers = {
    aws = aws.use1
  }
  source         = "../../modules/hcp_consul"
  for_each       = { for k, v in local.use1 : k => v if contains(keys(v), "hcp-consul") }
  hvn_id         = try(local.use1[each.key].hcp-consul.hvn_id, var.hvn_id)
  cloud_provider = try(local.use1[each.key].hcp-consul.cloud_provider, var.cloud_provider)
  #region             = local.use1[each.key].region
  cidr_block         = try(local.use1[each.key].hcp-consul.cidr_block, var.hvn_cidr_block)
  cluster_id         = try(local.use1[each.key].hcp-consul.cluster_id, var.cluster_id)
  tier               = try(local.use1[each.key].hcp-consul.tier, "development")
  min_consul_version = try(local.use1[each.key].hcp-consul.min_consul_version, var.min_consul_version)
  public_endpoint    = true
}

# Create use1 VPCs defined in local.use1
module "vpc-use1" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  providers = {
    aws = aws.use1
  }
  source                   = "terraform-aws-modules/vpc/aws"
  version                  = "~> 3.0"
  for_each                 = local.use1
  name                     = try(local.use1[each.key].vpc.name, "${var.prefix}-${each.key}-vpc")
  cidr                     = local.use1[each.key].vpc.cidr
  azs                      = [data.aws_availability_zones.use1.names[0], data.aws_availability_zones.use1.names[1]]
  private_subnets          = local.use1[each.key].vpc.private_subnets
  public_subnets           = local.use1[each.key].vpc.public_subnets
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
  flow_log_cloudwatch_log_group_name_prefix = "/aws/${local.use1[each.key].vpc.name}"
  flow_log_cloudwatch_log_group_name_suffix = "flow"

  tags = {
    Terraform  = "true"
    Owner      = "${var.prefix}"
    transit_gw = "true"
  }
  private_subnet_tags = {
    Tier                                                                              = "Private"
    "kubernetes.io/role/internal-elb"                                                 = 1
    "kubernetes.io/cluster/${try(local.use1[each.key].eks.cluster_name, var.prefix)}" = "shared"
  }
  public_subnet_tags = {
    Tier                                                                              = "Public"
    "kubernetes.io/role/elb"                                                          = 1
    "kubernetes.io/cluster/${try(local.use1[each.key].eks.cluster_name, var.prefix)}" = "shared"
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

# Create 1+ Transit gateways to connect VPCs to the HVN
module "tgw-use1" {
  # TransitGateway: https://registry.terraform.io/modules/terraform-aws-modules/transit-gateway/aws/latest
  providers = {
    aws = aws.use1
  }
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "2.8.2"

  for_each                              = { for k, v in local.use1 : k => v if contains(keys(v), "tgw") }
  description                           = "${var.prefix}-${each.key}-tgw - AWS Transit Gateway"
  name                                  = try(local.use1[each.key].tgw.name, "${var.prefix}-${each.key}-tgw")
  enable_auto_accept_shared_attachments = try(local.use1[each.key].tgw.enable_auto_accept_shared_attachments, true) # When "true" there is no need for RAM resources if using multiple AWS accounts
  ram_allow_external_principals         = try(local.use1[each.key].tgw.ram_allow_external_principals, true)
  amazon_side_asn                       = 64532
  tgw_default_route_table_tags = {
    name = "${var.prefix}-${each.key}-tgw-default_rt"
  }
  tags = {
    project = "${var.prefix}-${each.key}-tgw"
  }
}

# Attach 1+ Transit Gateways to each VPC and create routes for the private subnets
module "tgw_vpc_attach_use1" {
  source = "../../modules/aws_tgw_vpc_attach"
  providers = {
    aws = aws.use1
  }
  #for_each = local.vpc_tgw_locations_map_use1
  for_each           = local.tgw_vpc_attachments_map_use1
  subnet_ids         = module.vpc-use1[each.value.vpc_env].private_subnets
  transit_gateway_id = module.tgw-use1[each.value.tgw_env].ec2_transit_gateway_id
  vpc_id             = module.vpc-use1[each.value.vpc_env].vpc_id
  tags = {
    project = "${var.prefix}-${each.key}-tgw"
  }
}

# Attach HCP HVN to TGW and create routes from HVN to VPCs
module "aws_hcp_tgw_attach_use1" {
  providers = {
    aws = aws.use1
  }
  source                        = "../../modules/aws_hcp_tgw_attach"
  for_each                      = local.hvn_tgw_attachments_map_use1
  ram_resource_share_name       = "${local.use1[each.value.tgw_env].tgw.name}-ram"
  hvn_provider_account_id       = module.hcp_consul_use1[each.value.hvn_env].provider_account_id
  tgw_resource_association_arn  = module.tgw-use1[each.value.tgw_env].ec2_transit_gateway_arn
  hvn_id                        = module.hcp_consul_use1[each.value.hvn_env].hvn_id
  transit_gateway_attachment_id = "${local.use1[each.value.tgw_env].tgw.name}-id"
  transit_gateway_id            = module.tgw-use1[each.value.tgw_env].ec2_transit_gateway_id
  # Define TGW private_route_cidr_list for specific routes, or use default list of all VPC routable_cidr_blocks
  hvn_route_cidr_list = try(local.use1[each.value.hvn_env].hcp-consul.hvn_private_route_cidr_list, local.all_routable_cidr_blocks_use1)
  hvn_link            = module.hcp_consul_use1[each.value.hvn_env].hvn_self_link
  hvn_route_id        = var.prefix
}

# Create additional private routes between VPCs so they can see each other.
module "route_add_use1" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.use1
  }
  for_each               = local.vpc_routes_map_use1
  route_table_id         = module.vpc-use1[each.value.target_vpc].private_route_table_ids[0]
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.tgw-use1[each.value.tgw_env].ec2_transit_gateway_id
  depends_on             = [module.tgw_vpc_attach_use1]
}
#Add private routes to public route table to support SSH from bastion host.
module "route_public_add_use1" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.use1
  }
  for_each               = local.vpc_routes_map_use1
  route_table_id         = module.vpc-use1[each.value.target_vpc].public_route_table_ids[0]
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.tgw-use1[each.value.tgw_env].ec2_transit_gateway_id
  depends_on             = [module.tgw_vpc_attach_use1]
}
# Create static HVN route with local.use1.use1-shared.hcp-consul.cidr_block
module "route_add_hcp_use1" {
  source = "../../modules/aws_route_add"
  providers = {
    aws = aws.use1
  }
  for_each               = local.vpc_tgw_cidr_map_use1
  route_table_id         = module.vpc-use1[each.value.vpc_env].private_route_table_ids[0]
  destination_cidr_block = local.hvn_cidrs_map_use1.hvn.cidr
  transit_gateway_id     = module.tgw-use1[each.value.tgw_env].ec2_transit_gateway_id
  depends_on             = [module.aws_hcp_tgw_attach_use1]
}

# Create EKS cluster per VPC defined in local.use1
module "eks-use1" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  providers = {
    aws = aws.use1
  }
  source                          = "../../modules/aws_eks_cluster"
  for_each                        = { for k, v in local.use1 : k => v if contains(keys(v), "eks") }
  cluster_name                    = try(local.use1[each.key].eks.cluster_name, local.name)
  cluster_version                 = try(local.use1[each.key].eks.eks_cluster_version, var.eks_cluster_version)
  cluster_endpoint_private_access = try(local.use1[each.key].eks.cluster_endpoint_private_access, true)
  cluster_endpoint_public_access  = try(local.use1[each.key].eks.cluster_endpoint_public_access, true)
  cluster_service_ipv4_cidr       = try(local.use1[each.key].eks.service_ipv4_cidr, "172.20.0.0/16")
  min_size                        = try(local.use1[each.key].eks.eks_min_size, var.eks_min_size)
  max_size                        = try(local.use1[each.key].eks.eks_max_size, var.eks_max_size)
  desired_size                    = try(local.use1[each.key].eks.eks_desired_size, var.eks_desired_size)
  vpc_id                          = module.vpc-use1[each.key].vpc_id
  subnet_ids                      = module.vpc-use1[each.key].private_subnets
  all_routable_cidrs              = local.all_routable_cidr_blocks_use1
  hcp_cidr                        = [local.hvn_cidrs_map_use1.hvn.cidr]
}
module "hcp_consul_policy-use1" {

  providers = {
    aws    = aws.use1
    consul = consul.use1
  }
  source            = "../../modules/hcp_consul_policy"
  for_each          = toset(local.ec2_service_list_use1)
  consul_datacenter = module.hcp_consul_use1[local.hvn_list_use1[0]].datacenter
  consul_service    = each.key

}
module "hcp_consul_ec2_iam_auth_method-use1" {
  providers = {
    aws    = aws.use1
    consul = consul.use1
  }
  source                = "../../modules/hcp_consul_ec2_iam_auth_method"
  ServerIDHeaderValue   = join("", regex("http?s://(.*)", module.hcp_consul_use1[local.hvn_list_use1[0]].consul_private_endpoint_url))
  BoundIAMPrincipalARNs = [module.hcp_consul_ec2_iam_profile-use1.instance_profile_arn]
}
module "hcp_consul_ec2_iam_profile-use1" {
  # Create default ec2 profile used by consul agents
  providers = {
    aws = aws.use1
  }
  source    = "../../modules/hcp_consul_ec2_iam_profile"
  role_name = "consul-use1"
}
module "hcp_consul_ec2_client-use1" {
  providers = {
    aws = aws.use1
  }
  source   = "../../modules/hcp_consul_ec2_client"
  for_each = local.ec2_map_use1

  hostname                        = local.ec2_map_use1[each.key].hostname
  ec2_key_pair_name               = local.ec2_map_use1[each.key].ec2_ssh_key
  vpc_id                          = module.vpc-use1[each.value.vpc_env].vpc_id
  prefix                          = var.prefix
  associate_public_ip_address     = each.value.associate_public_ip_address
  subnet_id                       = each.value.target_subnets == "public_subnets" ? module.vpc-use1[each.value.vpc_env].public_subnets[0] : module.vpc-use1[each.value.vpc_env].private_subnets[0]
  security_group_ids              = [module.sg-consul-agents-use1[each.value.vpc_env].securitygroup_id]
  consul_service                  = local.ec2_map_use1[each.key].service
  instance_profile_name           = module.hcp_consul_ec2_iam_profile-use1.instance_profile_name
  consul_acl_token_secret_id      = module.hcp_consul_policy-use1[local.ec2_map_use1[each.key].service].consul_service_api_token
  consul_datacenter               = module.hcp_consul_use1[local.hvn_list_use1[0]].datacenter
  consul_public_endpoint_url      = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_public_endpoint_url
  hcp_consul_ca_file              = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_ca_file
  hcp_consul_config_file          = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_config_file
  hcp_consul_root_token_secret_id = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_root_token_secret_id
}

module "sg-consul-agents-use1" {
  providers = {
    aws = aws.use1
  }
  source = "../../modules/aws_sg_consul_agents"
  #for_each              = local.use1
  for_each = { for k, v in local.use1 : k => v if contains(keys(v), "ec2") }
  #region                = local.use1[each.key].region
  security_group_create = true
  name_prefix           = "${each.key}-consul-agent-sg"
  vpc_id                = module.vpc-use1[each.key].vpc_id
  #vpc_cidr_block        = local.use1[each.key].vpc.cidr
  vpc_cidr_blocks     = concat(local.all_routable_cidr_blocks_use1, [local.use1[local.hvn_list_use1[0]].hcp-consul.cidr_block])
  private_cidr_blocks = local.all_routable_cidr_blocks_use1
}

module "sg-consul-dataplane-use1" {
  providers = {
    aws = aws.use1
  }
  source                = "../../modules/aws_sg_consul_dataplane"
  for_each              = { for k, v in local.use1 : k => v if contains(keys(v), "eks") }
  security_group_create = true
  name_prefix           = "${each.key}-consul-dataplane-sg" #eks-cluster-sg-${prefix}-${each.key}
  vpc_id                = module.vpc-use1[each.key].vpc_id
  vpc_cidr_blocks       = concat(local.all_routable_cidr_blocks_use1, [local.use1[local.hvn_list_use1[0]].hcp-consul.cidr_block])
  private_cidr_blocks   = local.all_routable_cidr_blocks_use1
}

data "template_file" "eks_clients_use1" {
  for_each = { for k, v in local.use1 : k => v if contains(keys(v), "eks") }

  template = file("${path.module}/../templates/consul_helm_client.tmpl")
  vars = {
    region_shortname            = "use1"
    cluster_name                = try(local.use1[each.key].eks.cluster_name, local.name)
    server_replicas             = try(local.use1[each.key].eks.eks_desired_size, var.eks_desired_size)
    datacenter                  = module.hcp_consul_use1[local.hvn_list_use1[0]].datacenter
    release_name                = "consul-${each.key}"
    consul_external_servers     = jsondecode(base64decode(module.hcp_consul_use1[local.hvn_list_use1[0]].consul_config_file)).retry_join[0]
    eks_cluster_endpoint        = module.eks-use1[each.key].cluster_endpoint
    consul_version              = var.consul_version
    consul_helm_chart_version   = var.consul_helm_chart_version
    consul_helm_chart_template  = var.consul_helm_chart_template
    consul_chart_name           = "consul"
    consul_ca_file              = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_ca_file
    consul_config_file          = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_config_file
    consul_root_token_secret_id = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_root_token_secret_id
    partition                   = try(local.use1[each.key].consul_partition, var.consul_partition)
    node_selector               = "nodegroup: default"
  }
}

resource "local_file" "use1" {
  for_each = { for k, v in local.use1 : k => v if contains(keys(v), "eks") }
  content  = data.template_file.eks_clients_use1[each.key].rendered
  filename = "${path.module}/consul_helm_values/auto-${local.use1[each.key].eks.cluster_name}.tf"
}

output "use1_regions" {
  value = { for k, v in local.use1 : k => data.aws_region.use1.name }
}
# output "use1_regions" {
#   value = { for k, v in local.use1 : k => local.use1[k].region }
# }
output "use1_projects" { # Used by ./scripts/kubectl_connect_eks.sh to loop through Proj/Env and Auth to EKS clusters
  value = [for proj in sort(keys(local.use1)) : proj]
}
# VPC
output "use1_vpc_ids" {
  value = { for env in sort(keys(local.use1)) : env => module.vpc-use1[env].vpc_id }
}

### EKS
output "use1_eks_cluster_endpoints" {
  description = "Endpoint for your Kubernetes API server"
  value       = { for k, v in local.use1 : k => module.eks-use1[k].cluster_endpoint if contains(keys(v), "eks") }
}
output "use1_eks_cluster_names" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready"
  value       = { for k, v in local.use1 : k => local.use1[k].eks.cluster_name if contains(keys(v), "eks") }
}
### Transit Gateway
output "use1_ec2_transit_gateway_arn" {
  description = "EC2 Transit Gateway Amazon Resource Name (ARN)"
  value       = { for k, v in local.use1 : k => module.tgw-use1[k].ec2_transit_gateway_arn if contains(keys(v), "tgw") }
}

output "use1_ec2_transit_gateway_id" {
  description = "EC2 Transit Gateway identifier"
  value       = { for k, v in local.use1 : k => module.tgw-use1[k].ec2_transit_gateway_id if contains(keys(v), "tgw") }
}

output "use1_default_hvn_routes" {
  description = "A list of every VPCs routable cidr blocks are added to HVN Route unless (hcp-consul.hvn_private_route_cidr_list) is defined"
  value       = [for hvn_route in local.all_routable_cidr_blocks_use1 : hvn_route]
}
output "use1_vpc-tgw-cidr_routes_added" {
  value = [for vpc_route in sort(keys(local.vpc_routes_map_use1)) : vpc_route]
}
output "use1_ec2_ip" {
  value = { for k, v in local.ec2_map_use1 : k => module.hcp_consul_ec2_client-use1[k].ec2_ip }
}
output "use1_consul_config_file" {
  value = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_config_file
}
output "use1_consul_ca_file" {
  value = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_ca_file
}
output "use1_consul_private_endpoint_url" {
  value = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_private_endpoint_url
}
output "use1_consul_root_token_secret_id" {
  value = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_root_token_secret_id
}
output "use1_consul_service_api_token" {
  value = [for svc in local.ec2_service_list_use1 : module.hcp_consul_policy-use1[svc].consul_service_api_token]
}
output "use1_retry_join" {
  value = jsondecode(base64decode(module.hcp_consul_use1[local.hvn_list_use1[0]].consul_config_file)).retry_join[0]
}
output "use1_consul_public_endpoint_url" {
  value = module.hcp_consul_use1[local.hvn_list_use1[0]].consul_public_endpoint_url
}

output "use1_consul_ec2_iam_arn" {
  value = module.hcp_consul_ec2_iam_profile-use1.instance_profile_arn
}
output "use1_hcp_consul_ec2_iam_auth_config" {
  value = module.hcp_consul_ec2_iam_auth_method-use1.config_json
}