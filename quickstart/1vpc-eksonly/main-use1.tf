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
  default_route_table_name = "${var.prefix}-${each.key}-project1"

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
    Tier                              = "Private"
    "kubernetes.io/role/internal-elb" = 1
    # "kubernetes.io/cluster/${try(local.use1.project1.eks.consul1.cluster_name, var.prefix)}" = "shared"
  }
  public_subnet_tags = {
    Tier                     = "Public"
    "kubernetes.io/role/elb" = 1
    # "kubernetes.io/cluster/${try(local.use1.project1.eks.consul1.cluster_name, var.prefix)}" = "shared"
  }
  default_route_table_tags = {
    Name = "${var.prefix}-project1-default"
  }
  private_route_table_tags = {
    Name = "${var.prefix}-project1-private"
  }
  public_route_table_tags = {
    Name = "${var.prefix}-project1-public"
  }
}

module "eks-use1" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  providers = {
    aws = aws.use1
  }
  source                          = "../../modules/aws_eks_cluster"
  for_each                        = local.eks_map_use1
  cluster_name                    = try(local.eks_map_use1[each.key].cluster_name, local.name)
  cluster_version                 = try(local.eks_map_use1[each.key].eks_cluster_version, var.eks_cluster_version)
  cluster_endpoint_private_access = try(local.eks_map_use1[each.key].cluster_endpoint_private_access, true)
  cluster_endpoint_public_access  = try(local.eks_map_use1[each.key].cluster_endpoint_public_access, true)
  cluster_service_ipv4_cidr       = try(local.eks_map_use1[each.key].service_ipv4_cidr, "172.20.0.0/16")
  min_size                        = try(local.eks_map_use1[each.key].eks_min_size, var.eks_min_size)
  max_size                        = try(local.eks_map_use1[each.key].eks_max_size, var.eks_max_size)
  desired_size                    = try(local.eks_map_use1[each.key].eks_desired_size, var.eks_desired_size)
  instance_type                   = try(local.eks_map_use1[each.key].eks_instance_type, null)
  vpc_id                          = module.vpc-use1[each.value.vpc_env].vpc_id
  subnet_ids                      = module.vpc-use1[each.value.vpc_env].public_subnets
  all_routable_cidrs              = local.all_routable_cidr_blocks_use1
  #hcp_cidr                        = local.all_routable_cidr_blocks_use1
}

output "use1_regions" {
  value = { for k, v in local.use1 : k => data.aws_region.use1.name }
}
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
  value       = { for k, v in local.eks_map_use1 : k => module.eks-use1[k].cluster_endpoint }
}
output "use1_eks_cluster_names" {
  description = "The name/id of the EKS cluster. Will block on cluster creation until the cluster is really ready"
  value       = { for k, v in local.eks_map_use1 : k => module.eks-use1[k].cluster_name }
}

output "endpoint" {
  description = "Endpoint list for doctorconsul"
  value       = [for k in keys(local.eks_map_use1) : module.eks-use1[k].cluster_endpoint]
}