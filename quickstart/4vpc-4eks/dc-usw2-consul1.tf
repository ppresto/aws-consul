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
  value       = { for k, v in local.usw2 : k => module.eks-usw2[k].cluster_endpoint if contains(keys(v), "eks") }
}
output "usw2_eks_cluster_names" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready"
  value       = { for k, v in local.usw2 : k => local.usw2[k].eks.cluster_name if contains(keys(v), "eks") }
}