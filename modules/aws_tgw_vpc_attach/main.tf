# Get map of subnet ids that includes az
data "aws_subnet" "ids" {
  count = length(var.subnet_ids)
  #for_each = toset(var.subnet_ids) #broken, subnet_ids list unknown at apply time.
  id = var.subnet_ids[count.index]
}

# Invert map so each az has a list of subnets.
# ... activates grouping mode to add more then 1 subnet if it exists to the key value
locals {
  availability_zone_subnets = {
    for s in data.aws_subnet.ids : s.availability_zone => s.id...
  }
}

# Create attachment to 1 subnet in each AZ.  This is an AWS requirement.  All subnets in AZ will inherit tgw.
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  subnet_ids         = [for subnet_ids in local.availability_zone_subnets : subnet_ids[0]]
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  tags               = var.tags
}