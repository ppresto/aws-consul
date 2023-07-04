resource "hcp_hvn_peering_connection" "east_to_west" {
  count = try(local.use1["use1-shared"].hcp-consul.hvn_to_hvn_peering_enabled, false) == true && try(local.usw2["usw2-shared"].hcp-consul.hvn_to_hvn_peering_enabled, false) == true ? 1 : 0
  hvn_1 = module.hcp_consul_use1["use1-shared"].hvn_self_link
  hvn_2 = module.hcp_consul_usw2["usw2-shared"].hvn_self_link
}