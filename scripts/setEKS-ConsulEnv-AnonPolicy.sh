#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

kubectl config use-context usw2-app1

export CONSUL_HTTP_ADDR=$(kubectl -n consul get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname')
export CONSUL_HTTP_TOKEN=$(kubectl -n consul get secret consul-bootstrap-acl-token --template "{{.data.token | base64decode }}")

env | grep CONSUL_HTTP


if [[ -z $(consul acl policy read -name "anonymous-token-policy" -format=json | jq -r '.Rules' | grep "agent_prefix") ]]; then
# Update anonymous policy with agent "read".  This allows prometheus to read /metrics.
# FYI: Metrics requires http port 8500 to be listening.
echo
echo "Updating Policy: anonymous-token-policy"
echo
consul acl policy update -name "anonymous-token-policy" -rules - <<EOT
partition_prefix "" {
  namespace_prefix "" {
    node_prefix "" {
       policy = "read"
    }
    service_prefix "" {
       policy = "read"
    }
  }
  agent_prefix "" {
    policy = "read"
  }
}
EOT
else
    echo
    echo "Policy Updated Already: anonymous-token-policy"
    echo
    consul acl policy read -name "anonymous-token-policy" -format=json | jq -r '.Rules'
fi