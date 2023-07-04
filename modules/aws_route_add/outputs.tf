output "vpc_routes" {
  description = "Map of VPC route objects"
  value       = aws_route.this
}