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
}

resource "local_file" "eks_clients_usw2" {
  for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }
  content  = templatefile("${path.module}/../templates/consul_helm_client.tmpl",
    {
      region_shortname            = "usw2"
    cluster_name                = try(local.usw2[each.key].eks.cluster_name, local.name)
    server_replicas             = try(local.usw2[each.key].eks.eks_desired_size, var.eks_desired_size)
    datacenter                  = try(local.usw2[each.key].eks.consul_datacenter, "dc1")
    consul_type                 = try(local.usw2[each.key].eks.consul_type, "server")
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

# resource "local_file" "usw2" {
#   for_each = { for k, v in local.usw2 : k => v if contains(keys(v), "eks") }
#   content  = data.template_file.eks_clients_usw2[each.key].rendered
#   filename = "${path.module}/consul_helm_values/auto-${local.usw2[each.key].eks.cluster_name}.tf"
# }

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