resource "consul_acl_auth_method" "aws_iam_auth" {
  name        = "aws_auth_method"
  type        = "aws-iam"
  description = "Use AWS IAM Auth to provision a token"

  config_json = jsonencode({
    "BoundIAMPrincipalARNs" : "${var.BoundIAMPrincipalARNs}",
    "EnableIAMEntityDetails" : true,
    #"IAMEntityTags": ["consul-namespace"],
    "ServerIDHeaderValue" : "${var.ServerIDHeaderValue}",
    "MaxRetries" : 3,
    "IAMEndpoint" : "https://iam.amazonaws.com/",
    "STSEndpoint" : "https://sts.us-east-1.amazonaws.com/",
    "AllowedSTSHeaderValues" : ["X-Extra-Header"]
  })
  # config_json = jsonencode({
  #   "BoundIAMPrincipalARNs": ["arn:aws:iam::729755634065:instance-profile/consul_profile"],
  #   "EnableIAMEntityDetails": true,
  #   #"IAMEntityTags": ["consul-namespace"],
  #   "ServerIDHeaderValue": "presto-cluster-usw2.private.consul.328306de-41b8-43a7-9c38-ca8d89d06b07.aws.hashicorp.cloud",
  #   "MaxRetries": 3,
  #   "IAMEndpoint": "https://iam.amazonaws.com/",
  #   "STSEndpoint": "https://sts.us-east-1.amazonaws.com/",
  #   "AllowedSTSHeaderValues": ["X-Extra-Header"]
  # })
}