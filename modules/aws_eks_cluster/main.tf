# EBS Policy to enable ebs csi driver for persistant volume claims
data "aws_iam_policy" "ebscsi" {
  name = "AmazonEBSCSIDriverPolicy"
}

# Create EKS cluster
module "eks" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_service_ipv4_cidr       = var.cluster_service_ipv4_cidr
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  #control_plane_subnet_ids              = var.subnet_ids
  cluster_addons = {
    #coredns = {
    #  resolve_conflicts = "OVERWRITE"
    #}
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      #addon_version = "v1.13.3-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      most_recent = true
      #service_account_role_arn = data.aws_iam_policy.ebscsi.arn
      #addon_version = "v1.21.0-eksbuild.1"
    }
  }
  create_kms_key = true

  cluster_security_group_additional_rules = {
    # Allow other Internally routable CIDRs ingress access to cluster
    "${var.cluster_name}_ingress_routable_cidrs" = {
      description = "Ingress from cluster routable networks"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = concat(var.all_routable_cidrs, var.hcp_cidr)
    }
  }

  node_security_group_additional_rules = {
    "${var.cluster_name}_ingress_self_all" = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    "${var.cluster_name}_ingress_cluster_all" = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    "${var.cluster_name}_ingress_hcp_to_eks" = {
      description = "HCP Cluster to all EKS Nodes to support MGW Peering"
      protocol    = "tcp"
      from_port   = 8443
      to_port     = 8443
      type        = "ingress"
      cidr_blocks = var.hcp_cidr
    }
    "${var.cluster_name}_ingress_envoy_to_envoy" = {
      description = "HCP Cluster to all EKS Nodes to support MGW Peering"
      protocol    = "tcp"
      from_port   = 20000
      to_port     = 22000
      type        = "ingress"
      cidr_blocks = var.all_routable_cidrs
    }
    "${var.cluster_name}_ingress_eks_to_eks" = {
      description = "EKS Cluster to support MGW"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = var.hcp_cidr
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = 50
    instance_types = [var.instance_type]

    iam_role_additional_policies = {
      additional = data.aws_iam_policy.ebscsi.arn
    }
  }
  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    default_node_group = {
      # Remote access cannot be specified with a launch template
      # remote_access = {
      #   ec2_ssh_key               = var.ec2_key_pair_name
      #   source_security_group_ids = [module.sg-consul-dataplane-usw2[each.key].securitygroup_id]
      # }
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size
    }
  }
}

# Create AWS LoadBalancer Controller IAM Policy and Role for EKS cluster.
# Role
# arn:aws:iam::729755634065:role/${module.eks.cluster_name}-load-balancer-controller
module "lb_irsa" {
  source                                 = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name                              = "${module.eks.cluster_name}-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# The below section requires the correct kubernetes and helm providers to be setup.
# Providers can't be dynamically configured to support multiple eks clusters so code below is disabled.
# Instead use ./scripts/install_awslb_controller.sh to install the AWS LB controller in all eks clusters.
#
# ./scripts/install_awslb_controller.sh
# - Creates AWS LB Controller service account
# - Applys the above IAM role to the service account
# - Uses Helm to install the AWS LB controller with the sa

# resource "kubernetes_service_account" "lb_controller" {
#   metadata {
#     name      = "aws-load-balancer-controller"
#     namespace = "kube-system"
#     labels = {
#       "app.kubernetes.io/component" = "controller"
#       "app.kubernetes.io/name"      = "aws-load-balancer-controller"
#     }
#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.lb_irsa.iam_role_arn
#     }
#   }
# }

# resource "helm_release" "lb_controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"

#   set {
#     name  = "clusterName"
#     value = var.cluster_name
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = false
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = kubernetes_service_account.lb_controller.metadata[0].name
#   }
# }

# helm install -n kube-system