/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

resource "helm_release" "consul_secondary" {
  count            = var.primary_datacenter ? 0 : 1
  chart            = var.chart_name
  create_namespace = var.create_namespace
  name             = var.release_name
  namespace        = var.kubernetes_namespace
  repository       = var.chart_repository
  timeout          = 900
  version          = var.consul_helm_chart_version

  values     = [data.template_file.consul-secondary[0].rendered]
  depends_on = [kubernetes_namespace.consul, kubernetes_secret.federation_secret[0]]
}

data "template_file" "consul-secondary" {
  count    = var.primary_datacenter ? 0 : 1
  template = file("${path.module}/templates/${var.consul_helm_chart_template}")
  vars = {
    consul_version            = var.consul_version
    consul_helm_chart_version = var.consul_helm_chart_version
    server_replicas           = var.server_replicas
    datacenter                = var.datacenter
    aks_cluster               = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
    primary_datacenter_name   = var.primary_datacenter_name
  }
}
resource "local_file" "consul-secondary" {
  count    = var.primary_datacenter ? 0 : 1
  content  = data.template_file.consul-secondary[0].rendered
  filename = "./yaml/auto-${var.release_name}-values.yaml"
}

resource "kubernetes_secret" "consul_license_secondary" {
  count = var.primary_datacenter ? 0 : 1
  metadata {
    name      = "consul-ent-license"
    namespace = var.kubernetes_namespace
  }

  data = {
    "key" = var.consul_license
  }
}

data "azurerm_key_vault" "federation" {
  count               = var.primary_datacenter ? 0 : 1
  name                = var.azure_key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

data "azurerm_key_vault_secret" "federation" {
  count        = var.primary_datacenter ? 0 : 1
  name         = var.azure_key_vault_secret_name
  key_vault_id = data.azurerm_key_vault.federation[0].id
}

resource "kubernetes_secret" "federation_secret" {
  count = var.primary_datacenter ? 0 : 1
  metadata {
    name      = "consul-federation"
    namespace = var.kubernetes_namespace
  }

  data = jsondecode(data.azurerm_key_vault_secret.federation[0].value)
  depends_on = [
    data.azurerm_key_vault_secret.federation[0]
  ]
}