# HVN belongs to an AWS organization managed by HashiCorp, first define an AWS resource share
# that allows the two organizations to share resources.
resource "aws_ram_resource_share" "hcpc" {
  name                      = var.ram_resource_share_name
  allow_external_principals = true
}
resource "aws_ram_principal_association" "example" {
  resource_share_arn = aws_ram_resource_share.hcpc.arn
  principal          = var.hvn_provider_account_id
}

resource "aws_ram_resource_association" "example" {
  resource_share_arn = aws_ram_resource_share.hcpc.arn
  resource_arn       = var.tgw_resource_association_arn
}

# The aws tgw module is configured to auto accept attachments so just create the attachment.
resource "hcp_aws_transit_gateway_attachment" "example" {
  depends_on = [
    aws_ram_principal_association.example,
    aws_ram_resource_association.example,
  ]

  hvn_id                        = var.hvn_id
  transit_gateway_attachment_id = var.transit_gateway_attachment_id
  transit_gateway_id            = var.transit_gateway_id
  resource_share_arn            = aws_ram_resource_share.hcpc.arn
}

#Finally define the HCP Route to the VPC CIDR
resource "hcp_hvn_route" "route" {
  for_each         = toset(var.hvn_route_cidr_list)
  hvn_link         = var.hvn_link
  hvn_route_id     = replace(replace("${var.hvn_route_id}-${each.key}", ".", "-"), "/", "-")
  destination_cidr = each.key
  target_link      = hcp_aws_transit_gateway_attachment.example.self_link
}