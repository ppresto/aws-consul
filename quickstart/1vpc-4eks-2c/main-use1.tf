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
  subnet_ids                      = module.vpc-use1[each.value.vpc_env].private_subnets
  all_routable_cidrs              = local.all_routable_cidr_blocks_use1
  #hcp_cidr                        = local.all_routable_cidr_blocks_use1
}

resource "local_file" "test" {
  for_each = local.eks_map_use1
  content = templatefile("${path.module}/../templates/consul_helm_client.tmpl",
    {
      region_shortname            = "use1"
      cluster_name                = try(local.eks_map_use1[each.key].cluster_name, local.name)
      server_replicas             = try(local.eks_map_use1[each.key].eks_desired_size, var.eks_desired_size)
      datacenter                  = try(local.eks_map_use1[each.key].consul_datacenter, "dc1")
      consul_type                 = try(local.eks_map_use1[each.key].consul_type, "client")
      release_name                = "consul-${each.key}"
      consul_external_servers     = "NO_HCP_SERVERS"
      eks_cluster_endpoint        = module.eks-use1[each.key].cluster_endpoint
      consul_version              = var.consul_version
      consul_helm_chart_version   = var.consul_helm_chart_version
      consul_helm_chart_template  = try(local.eks_map_use1[each.key].consul_helm_chart_template, var.consul_helm_chart_template)
      consul_chart_name           = "consul"
      consul_ca_file              = ""
      consul_config_file          = ""
      consul_root_token_secret_id = ""
      partition                   = try(local.eks_map_use1[each.key].consul_partition, var.consul_partition)
      node_selector               = "" #K8s node label to target deployment too.
  })
  filename = "${path.module}/consul_helm_values/auto-${local.eks_map_use1[each.key].cluster_name}.tf"
}

module "consul_ec2_iam_profile-use1" {
  # Create default ec2 profile used by consul agents
  providers = {
    aws = aws.use1
  }
  source = "../../modules/hcp_consul_ec2_iam_profile"
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
  instance_profile_name           = module.consul_ec2_iam_profile-use1.instance_profile_name
  consul_acl_token_secret_id      = "INPUT_SVC_ACL_TOKEN_SECRET_ID"
  consul_datacenter               = "dc1"
  consul_public_endpoint_url      = "INPUT_CONSUL_URL"
  hcp_consul_ca_file              = "INPUT_CONSUL_CA"
  hcp_consul_config_file          = "INPUT_CONSUL_CONFIG_FILE"
  hcp_consul_root_token_secret_id = "INPUT_CONSUL_ROOT_TOKEN"
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
  vpc_cidr_blocks     = local.all_routable_cidr_blocks_use1
  private_cidr_blocks = local.all_routable_cidr_blocks_use1
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
  value       = { for k, v in local.use1.project1.eks : k => local.use1.project1.eks[k].cluster_name }
}

output "use1_ec2_ip" {
  value = { for k, v in local.ec2_map_use1 : k => module.hcp_consul_ec2_client-use1[k].ec2_ip }
}

output "use1_ec2_dns" {
  value = { for k, v in local.ec2_map_use1 : k => module.hcp_consul_ec2_client-use1[k].ec2_dns }
}