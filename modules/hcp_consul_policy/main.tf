# Admin Partitions and Namespaces
# resource "consul_admin_partition" "pci" {
#   name        = "pci"
#   description = "PCI compliant environment"
# }
# resource "consul_namespace" "pci-payments" {
#   name        = "payments"
#   description = "Team 2 payments"
#   partition   = consul_admin_partition.pci.name
#   meta = {
#     foo = "bar"
#   }
# }
# resource "consul_namespace" "default-app-web" {
#   name        = "web"
#   description = "Web service"
#   partition   = "default"
#   meta = {
#     foo = "bar"
#   }
# }


# Service Policies and Tokens (api)
resource "consul_acl_policy" "service" {
  name        = var.consul_service
  datacenters = [var.consul_datacenter]
  rules       = <<-RULE
    service "${var.consul_service}*" {
      policy = "write"
      intenstions = "read"
    }

    service "${var.consul_service}-sidecar-proxy" {
      policy = "write"
    }

    service_prefix "" {
      policy = "read"
    }

    node_prefix "" {
      policy = "read"
    }
  RULE
}

# # Create Default DNS Lookup policy and attach to anonymous token.
# resource "consul_acl_policy" "dns-request" {
#   name  = "dns-request-policy"
#   rules = <<-RULE
#     namespace_prefix "" {
#       node_prefix "" {
#         policy = "read"
#       }
#       service_prefix "" {
#         policy = "read"
#       }
#       # prepared query rules are not allowed in namespaced policies
#       #query_prefix "" {
#       #  policy = "read"
#       #}
#     }
#     RULE
# }

# resource "consul_acl_token_policy_attachment" "attachment" {
#   token_id = "00000000-0000-0000-0000-000000000002"
#   policy   = consul_acl_policy.dns-request.name
# }

resource "consul_acl_token" "service" {
  description = "${var.consul_service} token"
  policies    = ["${consul_acl_policy.service.name}"]
  local       = true
}
data "consul_acl_token_secret_id" "service" {
  accessor_id = consul_acl_token.service.id
}