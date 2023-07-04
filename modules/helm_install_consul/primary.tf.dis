/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

resource "helm_release" "consul_primary" {
  count            = var.primary_datacenter && var.client == false ? 1 : 0
  chart            = var.chart_name
  create_namespace = var.create_namespace
  name             = var.release_name
  namespace        = var.kubernetes_namespace
  repository       = var.chart_repository
  timeout          = 900
  version          = var.consul_helm_chart_version

  values     = [data.template_file.consul-primary[0].rendered]
  depends_on = [kubernetes_namespace.consul]
}
data "template_file" "consul-primary" {
  count    = var.primary_datacenter && var.client == false ? 1 : 0
  template = file("${path.module}/templates/${var.consul_helm_chart_template}")
  vars = {
    consul_version            = var.consul_version
    server_replicas           = var.server_replicas
    datacenter                = var.datacenter
    partition                 = var.consul_partition
    consul_helm_chart_version = var.consul_helm_chart_version
  }
}
resource "local_file" "consul-primary" {
  count    = var.primary_datacenter && var.client == false ? 1 : 0
  content  = data.template_file.consul-primary[0].rendered
  filename = "./yaml/auto-${var.release_name}-values.yaml"
}

resource "kubernetes_secret" "consul_license_primary" {
  count = var.primary_datacenter && var.client == false ? 1 : 0
  metadata {
    name      = "consul-ent-license"
    namespace = var.kubernetes_namespace
  }

  data = {
    "key" = var.consul_license
  }
}

# Federation Token for WAN Federation
resource "azurerm_key_vault_secret" "federation" {
  count        = var.primary_datacenter && var.enable_cluster_peering == false ? 1 : 0
  name         = var.azure_key_vault_secret_name
  key_vault_id = var.azure_key_vault_id
  value        = jsonencode(data.kubernetes_secret.federation_secret[0].data)
}

data "kubernetes_secret" "federation_secret" {
  count = var.primary_datacenter && var.enable_cluster_peering == false ? 1 : 0
  metadata {
    name      = "consul-federation"
    namespace = var.kubernetes_namespace
  }

  depends_on = [helm_release.consul_primary[0]]
}
# Consul CA cert needed for agentless AKS clusters
resource "azurerm_key_vault_secret" "consul-ca-cert" {
  count        = var.client == false && var.enable_cluster_peering ? 1 : 0
  name         = "${var.datacenter}-ca-cert"
  key_vault_id = var.azure_key_vault_id
  value        = jsonencode(data.kubernetes_secret.consul-ca-cert-secret[0].data)
}
data "kubernetes_secret" "consul-ca-cert-secret" {
  count = var.client == false && var.enable_cluster_peering ? 1 : 0
  metadata {
    name      = "consul-ca-cert"
    namespace = var.kubernetes_namespace
  }

  depends_on = [helm_release.consul_primary[0]]
}

# Consul Bootstrap token needed by agentless AKS clusters
resource "azurerm_key_vault_secret" "consul-bootstrap-token" {
  count        = var.client == false && var.enable_cluster_peering ? 1 : 0
  name         = "${var.datacenter}-bootstrap-token"
  key_vault_id = var.azure_key_vault_id
  value        = jsonencode(data.kubernetes_secret.consul-bootstrap-secret[0].data)
}
data "kubernetes_secret" "consul-bootstrap-secret" {
  count = var.client == false && var.enable_cluster_peering ? 1 : 0
  metadata {
    name      = "consul-bootstrap-acl-token"
    namespace = var.kubernetes_namespace
  }

  depends_on = [helm_release.consul_primary[0]]
}

resource "kubectl_manifest" "proxy_defaults" {
  count     = var.client == false ? 1 : 0
  yaml_body = <<YAML
apiVersion: consul.hashicorp.com/v1alpha1
kind: ProxyDefaults
metadata:
  name: global
  namespace: "${var.kubernetes_namespace}"
spec:
  config:
    protocol: http
  meshGateway:
    mode: local
YAML

  depends_on = [helm_release.consul_primary[0]]
}
resource "kubectl_manifest" "mesh_defaults" {
  count = 0
  #count      = var.primary_datacenter && var.client == false ? 1 : 0
  yaml_body  = <<YAML
apiVersion: consul.hashicorp.com/v1alpha1
kind: Mesh
metadata:
  name: mesh
  namespace: "${var.kubernetes_namespace}"
spec:
  peering:
    peerThroughMeshGateways: true
YAML
  depends_on = [helm_release.consul_primary[0]]
}
