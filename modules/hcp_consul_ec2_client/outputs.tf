output "bastion_ssh_sg_id" {
  value = aws_security_group.bastion.id
}
output "ec2_ip" {
  value       = aws_instance.ec2.public_ip != "" ? aws_instance.ec2.public_ip : aws_instance.ec2.private_ip
  description = "Public IP address of bastion"
}

output "ec2_dns" {
  value       = aws_instance.ec2.public_ip != "" ? aws_instance.ec2.public_dns : aws_instance.ec2.private_dns
  description = "DNS address of host"
}
# output "consul_service_api_token" {
#   value = try(nonsensitive(data.consul_acl_token_secret_id.service[0].secret_id),"")
# }