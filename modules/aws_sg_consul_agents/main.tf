resource "aws_security_group" "consul_server" {
  count       = var.security_group_create == true ? 1 : 0
  name_prefix = var.name_prefix
  description = "Firewall for the consul server."
  vpc_id      = var.vpc_id
  tags = merge(
    { "Name" = "${var.name_prefix}" },
    { "Owner" = "presto" }
  )
}

#
###  Consul Server Ingress
#

resource "aws_security_group_rule" "consul_server_allow_server_8301" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8301
  to_port           = 8301
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "Used to handle gossip from server"
}
resource "aws_security_group_rule" "consul_server_allow_server_8301_udp" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "udp"
  from_port         = 8301
  to_port           = 8301
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "Used to handle gossip from server"
}

#
### Consul Server Egress
#
resource "aws_security_group_rule" "hcp_tcp_RPC_from_clients" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 8300
  to_port           = 8300
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "For RPC communication between clients and servers"
}
resource "aws_security_group_rule" "hcp_tcp_server_gossip" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 8301
  to_port           = 8301
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "Server to server gossip communication"
}
resource "aws_security_group_rule" "hcp_udp_server_gossip" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "egress"
  protocol          = "udp"
  from_port         = 8301
  to_port           = 8301
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "Server to server gossip communication"
}
resource "aws_security_group_rule" "hcp_tcp_https" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "The HTTPS API"
}
resource "aws_security_group_rule" "hcp_tcp_grpc" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 8502
  to_port           = 8502
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "GRPC for agentless dataplane support"
}

#
### Envoy Proxy - Int Service to Service
#
resource "aws_security_group_rule" "eks_envoy" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 20000
  to_port           = 20000
  cidr_blocks       = var.private_cidr_blocks
  description       = "Allow envoy traffic."
}
resource "aws_security_group_rule" "eks_ingressgw" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 21000
  to_port           = 21255
  cidr_blocks       = var.private_cidr_blocks
  description       = "ingress k8s HC."
}

resource "aws_security_group_rule" "eks_meshgw" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8443
  to_port           = 8443
  cidr_blocks       = var.private_cidr_blocks
  description       = "ingress k8s HC."
}

resource "aws_security_group_rule" "fake-service-nonmesh" {
  security_group_id = var.security_group_create == true ? aws_security_group.consul_server[0].id : var.security_group_id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "The HTTPS API"
}