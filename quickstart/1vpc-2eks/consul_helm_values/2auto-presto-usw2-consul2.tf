module "consul_presto-usw2-consul2" {
  source   = "../../../modules/helm_install_consul"
  providers = { aws = aws.usw2 }
  release_name  = "consul-vpc1-consul2"
  chart_name         = "consul"
  cluster_name         = "presto-usw2-consul2"
  datacenter           = "dc2"
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
  eks_cluster_endpoint       = "https://1263B6079ECD32365D6E3961B8F3613C.gr7.us-west-2.eks.amazonaws.com"
  hcp_consul_ca_file             = ""
  hcp_consul_config_file             = ""
  hcp_consul_root_token_secret_id = ""
  node_selector = ""
}

