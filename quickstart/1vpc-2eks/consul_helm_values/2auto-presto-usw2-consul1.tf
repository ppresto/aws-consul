module "consul_presto-usw2-consul1" {
  source   = "../../../modules/helm_install_consul"
  providers = { aws = aws.usw2 }
  release_name  = "consul-vpc1-consul1"
  chart_name         = "consul"
  cluster_name         = "presto-usw2-consul1"
  datacenter           = "dc1"
  consul_partition     = "default"
  consul_type          = "server"
  server_replicas      = "1"
  consul_version       = "1.16.0-ent"
  consul_license       = file("../../../files/consul.lic")
  consul_helm_chart_template = "values-server-sd.yaml"
  #consul_helm_chart_template  = "values-dataplane-hcp.yaml"
  #consul_helm_chart_template = "values-server.yaml"
  #consul_helm_chart_template = "values-dataplane.yaml"
  consul_helm_chart_version  = "1.2.0"
  consul_external_servers    = "NO_HCP_SERVERS" #HCP private endpoint address
  eks_cluster_endpoint       = "https://8102025D967D86F0B44C55F530848129.gr7.us-west-2.eks.amazonaws.com"
  hcp_consul_ca_file             = ""
  hcp_consul_config_file             = ""
  hcp_consul_root_token_secret_id = ""
  node_selector = ""
}

