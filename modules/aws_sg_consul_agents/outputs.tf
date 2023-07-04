

output "securitygroup_id" {
  description = "Consul Server Security Group ID"
  value       = aws_security_group.consul_server[0].id
}