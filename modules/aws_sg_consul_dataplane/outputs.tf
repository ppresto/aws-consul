

output "securitygroup_id" {
  description = "Consul Server Security Group ID"
  value       = try(aws_security_group.consul_dataplane[0].id, var.security_group_id)
}