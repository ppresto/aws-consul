# Create Default Agent 'read' policy for metrics and attach to anonymous token.
resource "consul_acl_policy" "metrics" {
  name  = "metrics-policy"
  rules = <<-RULE
    agent "" {
      policy = "read"
    }
    RULE
}

resource "consul_acl_token_policy_attachment" "attachment" {
  token_id = "00000000-0000-0000-0000-000000000002"
  policy   = consul_acl_policy.metrics.name
}