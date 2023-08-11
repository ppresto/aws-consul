locals {
  # Infrastructure Configuration
  use1 = {
    # Project Name
    "project1" = {
      # Configure Project VPC
      "vpc" = {
        "name" : "${var.prefix}-use1-consul"
        "cidr" : "10.17.0.0/16",
        "private_subnets" : ["10.17.8.0/22", "10.17.20.0/22", "10.17.32.0/22", "10.17.40.0/22"],
        "public_subnets" : ["10.17.108.0/22", "10.17.120.0/22", "10.17.132.0/22"],
        "routable_cidr_blocks" : ["10.17.0.0/16"]
      }
      # Configure Project EKS Resources
      "eks" = {
        "nEKS0" = {
          "cluster_name" : "nEKS0",
          "cluster_version" : var.eks_cluster_version,
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "cluster_endpoint_private_access" : true,
          "cluster_endpoint_public_access" : true,
          "eks_min_size" : 1,
          "eks_max_size" : 3,
          "eks_desired_size" : 1           # used for pool size and consul replicas size
          "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
          #"service_ipv4_cidr" : "10.17.16.0/22" #Can't overlap with VPC CIDR
          "consul_helm_chart_template" : "values-server.yaml"
          "consul_datacenter" : "dc3"
          "consul_type" : "server"
        }
        "nEKS1" = {
          "cluster_name" : "nEKS1",
          "cluster_version" : var.eks_cluster_version,
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "cluster_endpoint_private_access" : true,
          "cluster_endpoint_public_access" : true,
          "eks_min_size" : 1,
          "eks_max_size" : 3,
          "eks_desired_size" : 1           # used for pool size and consul replicas size
          "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
          #"service_ipv4_cidr" : "10.17.16.0/22" #Can't overlap with VPC CIDR
          "consul_helm_chart_template" : "values-dataplane.yaml"
          "consul_datacenter" : "dc3"
          "consul_type" : "dataplane"
        }
        "nEKS2" = {
          "cluster_name" : "nEKS2",
          "cluster_version" : var.eks_cluster_version,
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "cluster_endpoint_private_access" : true,
          "cluster_endpoint_public_access" : true,
          "eks_min_size" : 1,
          "eks_max_size" : 3,
          "eks_desired_size" : 1           # used for pool size and consul replicas size
          "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
          #"service_ipv4_cidr" : "10.17.16.0/22" #Can't overlap with VPC CIDR
          "consul_helm_chart_template" : "values-server.yaml"
          "consul_datacenter" : "dc4"
          "consul_type" : "server"
        }
        "nEKS3" = {
          "cluster_name" : "nEKS3",
          "cluster_version" : var.eks_cluster_version,
          "ec2_ssh_key" : var.ec2_key_pair_name,
          "cluster_endpoint_private_access" : true,
          "cluster_endpoint_public_access" : true,
          "eks_min_size" : 1,
          "eks_max_size" : 3,
          "eks_desired_size" : 1           # used for pool size and consul replicas size
          "eks_instance_type" : "m5.large" # m5.large(2cpu,8mem), m5.2xlarge(8cpu,32mem)
          #"service_ipv4_cidr" : "10.17.16.0/22" #Can't overlap with VPC CIDR
          "consul_helm_chart_template" : "values-dataplane.yaml"
          "consul_datacenter" : "dc4"
          "consul_type" : "dataplane"
        }
      }
      # Configure Project EC2 Resources
      # "ec2" = {
      #   "vm1" = {
      #     "ec2_ssh_key" : var.ec2_key_pair_name
      #     "target_subnets" : "private_subnets"
      #     "associate_public_ip_address" : false
      #     "service" : "consul-esm"
      #   }
      #   "bastion" = {
      #     "ec2_ssh_key" : var.ec2_key_pair_name
      #     "target_subnets" : "public_subnets"
      #     "associate_public_ip_address" : true
      #   }
      # }
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

  # Create EKS Resource map per Proj/Env
  eks_location_use1 = flatten([for env, values in local.use1 : {
    "${env}" = values.eks
    }
  ])
  eks_location_map_use1 = { for item in local.eks_location_use1 : keys(item)[0] => values(item)[0] }
  # Flatten map by eks instance and inject Proj/Env.  For_each loop can now build every instance
  eks_use1 = flatten([for env, values in local.eks_location_map_use1 :
    flatten([for eks, attr in values : {
      "${env}-${eks}" = {
        "cluster_name"                    = attr.cluster_name
        "cluster_version"                 = attr.cluster_version
        "ec2_ssh_key"                     = attr.ec2_ssh_key
        "cluster_endpoint_private_access" = attr.cluster_endpoint_private_access
        "cluster_endpoint_public_access"  = attr.cluster_endpoint_public_access
        "eks_min_size"                    = attr.eks_min_size
        "eks_max_size"                    = attr.eks_max_size
        "eks_desired_size"                = attr.eks_desired_size
        "eks_instance_type"               = attr.eks_instance_type
        "consul_helm_chart_template"      = attr.consul_helm_chart_template
        "consul_datacenter"               = attr.consul_datacenter
        "consul_type"                     = attr.consul_type
        "vpc_env"                         = env
      }
    }])
  ])
  eks_map_use1 = { for item in local.eks_use1 : keys(item)[0] => values(item)[0] }

  # Create VPC tags for each project with EKS cluster_names to support AWS LB Controller
  eks_private_tags = {for env, values in local.eks_location_map_use1 :
    "${env}" => merge({for eks, attr in values :
        "kubernetes.io/cluster/${attr.cluster_name}" => "shared"
      },{Tier = "Private","kubernetes.io/role/internal-elb" = 1})
  }
  eks_public_tags = {for env, values in local.eks_location_map_use1 :
    "${env}" => merge({for eks, attr in values :
        "kubernetes.io/cluster/${attr.cluster_name}" => "shared"
      },{Tier = "Public","kubernetes.io/role/elb" = 1})
  }
}
