output "consul_service_api_token" {
  value = try(nonsensitive(data.consul_acl_token_secret_id.service.secret_id), "")
}