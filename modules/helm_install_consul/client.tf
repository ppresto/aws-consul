/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */


resource "kubernetes_namespace" "consul" {
  metadata {
    name = var.kubernetes_namespace
  }
}

resource "helm_release" "consul_client" {
  chart            = var.chart_name
  create_namespace = var.create_namespace
  name             = var.release_name
  namespace        = var.kubernetes_namespace
  repository       = var.chart_repository
  timeout          = 900
  version          = var.consul_helm_chart_version

  values     = [templatefile("${path.module}/templates/${var.consul_helm_chart_template}",
  {
    consul_version            = var.consul_version
    consul_helm_chart_version = var.consul_helm_chart_version
    server_replicas           = var.server_replicas
    cluster_name              = var.cluster_name
    datacenter                = var.datacenter
    partition                 = var.consul_partition
    eks_cluster               = var.eks_cluster_endpoint
    consul_external_servers   = var.consul_external_servers
    node_selector             = var.node_selector
  })]
  depends_on = [kubernetes_namespace.consul]
}

resource "local_file" "helm-values" {
  content  = templatefile("${path.module}/templates/${var.consul_helm_chart_template}",
  {
    consul_version            = var.consul_version
    consul_helm_chart_version = var.consul_helm_chart_version
    server_replicas           = var.server_replicas
    cluster_name              = var.cluster_name
    datacenter                = var.datacenter
    partition                 = var.consul_partition
    eks_cluster               = var.eks_cluster_endpoint
    consul_external_servers   = var.consul_external_servers
    node_selector             = var.node_selector
  })
  filename = "./yaml/auto-${var.release_name}-${var.consul_helm_chart_template}"
}

resource "kubernetes_secret" "consul_license_client" {
  metadata {
    name      = "consul-ent-license"
    namespace = var.kubernetes_namespace
  }
  data = {
    "key" = var.consul_license
  }
}

# Get Consul Cluster CA Certificate

resource "kubernetes_secret" "consul-ca-cert-hcp" {
  count = var.consul_helm_chart_template == "values-dataplane-hcp.yaml" ? 1 : 0
  metadata {
    name      = "consul-ca-cert"
    namespace = var.kubernetes_namespace
  }
  data = { "tls.crt" = var.hcp_consul_ca_file }
}
resource "kubernetes_secret" "consul-ca-cert" {
  count = var.consul_helm_chart_template != "values-dataplane-hcp.yaml" && var.consul_type == "dataplane" ? 1 : 0
  metadata {
    name      = "consul-ca-cert"
    namespace = var.kubernetes_namespace
  }
  binary_data = { "tls.crt" = var.hcp_consul_ca_file }
}

# Get Consul Cluster bootstrap token

resource "kubernetes_secret" "consul-bootstrap-token" {
  #count = var.consul_helm_chart_template != "values-dataplane-hcp.yaml" && var.consul_type == "dataplane" ? 1 : 0
  count = var.consul_type == "dataplane" ? 1 : 0
  metadata {
    name      = "consul-bootstrap-acl-token"
    namespace = var.kubernetes_namespace
  }
  data = { "token" = var.hcp_consul_root_token_secret_id }
}