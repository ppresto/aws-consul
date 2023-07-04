
variable "iam_teams" {
  default = {
    "team1" = {
      "gsa" : "gsa-tfc-team1",
      "namespace" : "tfc-team1",
      "k8s_sa" : "tfc-agent-dev",
      "roles" : ["compute.admin", "storage.objectAdmin"],
    },
    "team2" = {
      "gsa" : "gsa-tfc-team2",
      "namespace" : "tfc-team2",
      "k8s_sa" : "tfc-agent-dev",
      "roles" : ["storage.objectAdmin"],
    }
  }
}

variable "bq_iam_role_bindings" {

  default = {
    "member1" = {
      "dataset1" : ["role1", "role2", "role5"],
      "dataset2" : ["role3", "role2"],
    },
    "member2" = {
      "dataset3" : ["role1", "role4"],
      "dataset2" : ["role5"],
    }
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

variable "prefix" {
  description = "Unique name to identify all resources. Try using your name."
  type        = string
  default     = "presto"
}

locals {
  name                = "ex-${replace(basename(path.cwd), "_", "-")}"
  region_shortname    = join("", regex("([a-z]{2}).*-([a-z]).*-(\\d+)", var.region))
  private_cidr_blocks = ["10.0.0.0/10"]
  test                = var.iam_teams["team1"].roles
  team_config = flatten([for team, value in var.iam_teams :
    {
      "roles"  = value.roles
      "gsa"    = value.gsa
      "k8s_sa" = value.k8s_sa
    "namespace" = value.namespace }
  ])
  team_roles = flatten([for team, value in var.iam_teams :
    flatten([for role in value.roles :
      { "team" = team
      "role" = role }
    ])
  ])

  helper_list = flatten([for member, value in var.bq_iam_role_bindings :
    flatten([for dataset, roles in value :
      [for role in roles :
        { "member"  = member
          "dataset" = dataset
        "role" = role }
    ]])
  ])

  env_list = flatten([for dc, value in local.usw1 :
    {
      "${value.name}" = value #Full DC structure
      # "region" = value.region
      # "vpc_cidr" = value.vpc.cidr
      # "public-subnets" = value.vpc.public_subnets
      # "private-subnets" = value.vpc.private_subnets
      # "private-cidr-blocks" = value.vpc.private_cidr_blocks
    }
  ])
  env_private_cidrblocks = flatten([for dc, value in local.usw1 :
    flatten([for cidr in value.vpc.private_cidr_blocks :
      {
        "${value.name}" = {
          "name"                = value.name
          "private-cidr-blocks" = cidr
        }
      }
    ])
  ])

  usw1 = {
    "usw1-shared" = {
      "name" : "usw1-shared",
      "region" : "us-west-1",
      "vpc" = {
        "name" : "${var.prefix}--${local.region_shortname}-shared"
        "cidr" : "10.15.0.0/16",
        "private_subnets" : ["10.15.1.0/24", "10.15.2.0/24"],
        "public_subnets" : ["10.15.11.0/24", "10.15.12.0/24"],
        "private_cidr_blocks" : ["10.0.0.0/10"],
      }
      "tgw" = { #Only 1 TGW needed per region/data center.  Other VPC's can attach to it.
        "name" : "${var.prefix}-${local.region_shortname}-tgw",
        "enable_auto_accept_shared_attachments" : true,
        "ram_allow_external_principals" : true
      }
      "eks" = {
        "cluster_name" : "${var.prefix}-${local.region_shortname}-shared",
        "cluster_version" : "1.24",
        "ec2_ssh_key" : "keypair",
        "cluster_endpoint_private_access" : true,
        "cluster_endpoint_public_access" : true
      }
    },
    "usw1-app1" = {
      "name" : "usw1-app1",
      "region" : "us-west-1",
      "vpc" = {
        "name" : "${var.prefix}-${local.region_shortname}-app1"
        "cidr" : "10.16.0.0/16",
        "private_subnets" : ["10.16.1.0/24", "10.16.2.0/24"],
        "public_subnets" : ["10.16.11.0/24", "10.16.12.0/24"],
        "private_cidr_blocks" : ["10.0.0.0/10"]
      }
      "eks" = {}
    }
  }
  # iterate through datacenter and return vpn subnets for eks only 
  eks_subnets = flatten([for dc, values in local.usw1 : [
    for subnet-key, subnet in values.vpc.private_subnets :
    {
      "${dc}" = {
        "subnet" = subnet
      }
    } if contains(keys(values.vpc), "eks")
    ]
  ])

  tgw_list = flatten([for env, values in local.usw1 :
    [
      "${env}"
    ] if contains(keys(values), "tgw")
  ])
  vpc_tgw_locations = flatten([for env, values in local.usw1 :
    flatten([for tgw-key, tgw-val in local.tgw_list :
      {
        "${env}-tgw-${tgw-val}" = {
          "tgw_env" = tgw-val
          "vpc_env" = env
        }
      }
    ])
  ])
  vpc_tgw_cidr_routes = flatten([for env, values in local.usw1 :
    flatten([for tgw-key, tgw-val in local.tgw_list :
      flatten([for cidr in values.vpc.private_cidr_blocks :
        {
          "${env}-${cidr}" = {
            "tgw_env" = tgw-val
            "vpc_env" = env
            "cidr"    = cidr
          }
        }
      ])
    ])
  ])
  # transform the list into a map
  vpc_tgw_cidr_routes_map = { for item in local.vpc_tgw_cidr_routes :
    keys(item)[0] => values(item)[0]
  }
  vpc_tgw_locations_map = { for item in local.vpc_tgw_locations :
    keys(item)[0] => values(item)[0]
  }

}

output "tgw" {
  value = local.vpc_tgw_locations
}
output "vpc_tgw_cidr_routes" {
  value = local.vpc_tgw_cidr_routes
}

# test regex
output "region_shortname" {
  value = join("", regex("([a-z]{2}).*-([a-z]).*-(\\d+)", "us-west-2"))
}
output "test-regex" {
  value = regex("http?s://(.*)", "https://presto-cluster-usw2.private.consul.328306de-41b8-43a7-9c38-ca8d89d06b07.aws.hashicorp.cloud")
}