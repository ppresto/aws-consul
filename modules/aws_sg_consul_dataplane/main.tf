resource "aws_security_group" "consul_dataplane" {
  count       = var.security_group_create == true ? 1 : 0
  name_prefix = var.name_prefix
  description = "dataplane - Firewall for the consul server."
  vpc_id      = var.vpc_id
  tags = merge(
    { "Name" = "${var.name_prefix}" },
    { "Owner" = "presto" }
  )
}

resource "aws_security_group_rule" "hcp_tcp_https" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_dataplane[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "dataplane - The HTTPS API"
}
resource "aws_security_group_rule" "hcp_tcp_grpc" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_dataplane[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 8502
  to_port           = 8502
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "dataplane - GRPC for agentless dataplane support"
}

#
### Envoy Proxy - Int Service to Service
#
resource "aws_security_group_rule" "eks_envoy" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_dataplane[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 20000
  to_port           = 20000
  cidr_blocks       = var.private_cidr_blocks
  description       = "dataplane - Allow envoy traffic."
}
resource "aws_security_group_rule" "eks_ingressgw" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_dataplane[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 21000
  to_port           = 21255
  cidr_blocks       = var.private_cidr_blocks
  description       = "dataplane - ingress k8s HC."
}

resource "aws_security_group_rule" "eks_meshgw" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_dataplane[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8443
  to_port           = 8443
  cidr_blocks       = var.private_cidr_blocks
  description       = "dataplane - ingress k8s HC."
}