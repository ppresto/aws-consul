data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

# EBS Policy to enable ebs csi driver for persistant volume claims
data "aws_iam_policy" "ebscsi" {
  name = "AmazonEBSCSIDriverPolicy"
}

locals {
  name            = var.cluster_name
  cluster_version = var.cluster_version
  tags = {
    Example    = local.name
    GithubRepo = "aws-consul"
    GithubOrg  = "ppresto"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  vpc_id                         = var.vpc_id
  subnet_ids                     = var.subnet_ids

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  # Self managed node groups will not automatically create the aws-auth configmap
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

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
      description = "Allowed CIDRs can connect to EKS nodes with Mesh gateways to extend mesh"
      protocol    = "tcp"
      from_port   = 8443
      to_port     = 8443
      type        = "ingress"
      cidr_blocks = var.all_routable_cidrs
    }
  }

  self_managed_node_group_defaults = {
    ami_id        = data.aws_ami.eks_default.id
    instance_type = var.instance_type
    disk_size     = 50
    iam_role_additional_policies = {
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      AmazonEBSCSIDriverPolicy           = data.aws_iam_policy.ebscsi.arn
      #additional               = aws_iam_policy.additional.arn
    }
    timeouts = {
      create = "30m"
      update = "30m"
      delete = "30m"
    }
    # enable discovery of autoscaling groups by cluster-autoscaler
    autoscaling_group_tags = {
      "k8s.io/cluster-autoscaler/enabled" : true,
      "k8s.io/cluster-autoscaler/${local.name}" : "owned",
    }
  }

  self_managed_node_groups = {
    # Default node group - as provisioned by the module defaults
    default_node_group = {
      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=nodegroup=default'"
    }

    # Consul Node Group
    consul = {
      name            = "consul-self-managed"
      use_name_prefix = false
      subnet_ids      = [var.subnet_ids[0]]
      min_size        = var.min_size
      max_size        = var.max_size
      desired_size    = var.desired_size
      create_kms_key  = false

      placement_group = aws_placement_group.consul.id
      placement = {
        availability_zone = var.subnet_ids[0]
        group_name        = aws_placement_group.consul.id
      }
      create_iam_role          = true
      iam_role_name            = "self-managed-consul-${var.cluster_name}"
      iam_role_use_name_prefix = false
      iam_role_description     = "Self managed node group role"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }
      launch_template_name            = "self-managed-consul-${var.cluster_name}"
      launch_template_use_name_prefix = true
      launch_template_description     = "Self managed node group launch template"

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=nodegroup=consul'"
      tags = {
        placementgroup = "true"
      }
      taints = [
        {
          key    = "nodegroup"
          value  = "consul"
          effect = "NO_SCHEDULE"
        }
      ]
    }
    # Services
    services = {
      name            = "services-self-mng"
      use_name_prefix = false

      subnet_ids      = [var.subnet_ids[0]]
      placement_group = aws_placement_group.consul.id
      min_size        = var.min_size
      max_size        = var.max_size
      desired_size    = var.desired_size
      create_kms_key  = false

      bootstrap_extra_args    = "--kubelet-extra-args '--node-labels=nodegroup=services'"
      pre_bootstrap_user_data = <<-EOT
        export FOO=bar
      EOT

      post_bootstrap_user_data = <<-EOT
        echo "you are free little kubelet!"
      EOT

      placement = {
        availability_zone = var.subnet_ids[0]
        group_name        = aws_placement_group.consul.id
      }
      launch_template_name            = "${var.cluster_name}-services"
      launch_template_use_name_prefix = true
      launch_template_description     = "Self managed node group launch template"

      # block_device_mappings = {
      #   xvda = {
      #     device_name = "/dev/xvda"
      #     ebs = {
      #       volume_size           = 75
      #       volume_type           = "gp3"
      #       iops                  = 16000
      #       throughput            = 1000
      #       #encrypted             = true
      #       #kms_key_id            = module.ebs_kms_key.key_arn
      #       delete_on_termination = true
      #     }
      #   }
      # }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      ebs_optimized            = true
      enable_monitoring        = true
      create_iam_role          = true
      iam_role_name            = "${var.cluster_name}-services"
      iam_role_use_name_prefix = false
      iam_role_description     = "Self managed node group role"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }

      tags = {
        placementgroup = "true"
      }
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################


data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

resource "aws_placement_group" "consul" {
  name     = "${var.cluster_name}-pg"
  strategy = "cluster"
  tags = {
    placementGroup  = "true",
    applicationType = "eks"
  }
}

# module "key_pair" {
#   source  = "terraform-aws-modules/key-pair/aws"
#   version = "~> 2.0"

#   key_name_prefix    = local.name
#   create_private_key = true

#   tags = local.tags
# }

# module "ebs_kms_key" {
#   source  = "terraform-aws-modules/kms/aws"
#   version = "~> 1.5"

#   description = "Customer managed key to encrypt EKS managed node group volumes"

#   # Policy
#   key_administrators = [
#     data.aws_caller_identity.current.arn
#   ]

#   key_service_roles_for_autoscaling = [
#     # required for the ASG to manage encrypted volumes for nodes
#     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
#     # required for the cluster / persistentvolume-controller to create encrypted PVCs
#     module.eks.cluster_iam_role_arn,
#   ]

#   # Aliases
#   aliases = ["eks/${local.name}/ebs2"]

#   tags = local.tags
# }

# resource "aws_iam_policy" "additional" {
#   name        = "${local.name}-additional"
#   description = "Example usage of node additional policy"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "ec2:Describe*",
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#       },
#     ]
#   })

#   tags = local.tags
# }
