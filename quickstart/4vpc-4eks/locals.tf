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