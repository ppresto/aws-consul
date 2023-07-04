output "instance_profile_name" {
  value = aws_iam_instance_profile.consul_profile.name
}

output "instance_profile_arn" {
  value = aws_iam_instance_profile.consul_profile.arn
}