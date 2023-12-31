ec2_key_pair_name          = "ppresto-ptfe-dev-key"
eks_cluster_version        = "1.24"
min_consul_version         = "1.15.3"     #Version used when deploying HCP Consul
consul_version             = "1.15.2-ent" # Version used in helm values for dataplane and self-hosted setups
consul_helm_chart_version  = "1.1.1"
consul_helm_chart_template = "values-dataplane-hcp.yaml"
#consul_helm_chart_template = "values-server.yaml"
#consul_helm_chart_template = "values-dataplane.yaml"
consul_partition = "default"