## Bastion ec2

data "aws_region" "current" {}
data "aws_ssm_parameter" "ubuntu_1804_ami_id" {
  name = "/aws/service/canonical/ubuntu/server/18.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "ec2" {
  ami                  = var.use_latest_ami ? data.aws_ssm_parameter.ubuntu_1804_ami_id.value : var.ami_id
  instance_type        = "t3.micro"
  key_name             = var.ec2_key_pair_name
  iam_instance_profile = var.instance_profile_name
  #vpc_security_group_ids      = [aws_security_group.bastion.id]
  vpc_security_group_ids      = concat([aws_security_group.bastion.id], var.security_group_ids)
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  user_data                   = templatefile("${path.module}/templates/client-systemd.sh",
    {
      CONSUL_CA_FILE     = var.hcp_consul_ca_file
      CONSUL_CONFIG_FILE = var.hcp_consul_config_file
      CONSUL_ACL_TOKEN   = var.hcp_consul_root_token_secret_id
      SERVICE_ACL_TOKEN  = var.consul_acl_token_secret_id
      CONSUL_SERVICE     = var.consul_service
  })
  tags = merge(
    { "Name" = "${var.hostname}" },
    { "Project" = "${var.prefix}-${local.region_shortname}-${var.hostname}" }
  )
}
## Bastion SG
resource "aws_security_group" "bastion" {
  name_prefix = "${local.region_shortname}-bastion-sg"
  description = "Firewall for the bastion instance"
  vpc_id      = var.vpc_id
  tags = merge(
    { "Name" = "${local.region_shortname}-bastion-sg" },
    { "Project" = "${var.prefix}-${local.region_shortname}-ec2" }
  )
}

resource "aws_security_group_rule" "bastion_allow_22" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = var.allowed_bastion_cidr_blocks
  ipv6_cidr_blocks  = length(var.allowed_bastion_cidr_blocks_ipv6) > 0 ? var.allowed_bastion_cidr_blocks_ipv6 : null
  description       = "Allow SSH traffic."
}

resource "aws_security_group_rule" "bastion_allow_outbound" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = length(var.allowed_bastion_cidr_blocks_ipv6) > 0 ? ["::/0"] : null
  description       = "Allow any outbound traffic."
}
