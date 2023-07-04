output "vpc_attachment" {
  description = "Object with the Transit Gateway VPC attachment attributes"
  value       = aws_ec2_transit_gateway_vpc_attachment.this
}
output "vpc_attachment_id" {
  description = "Transit Gateway VPC attachment ID"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}