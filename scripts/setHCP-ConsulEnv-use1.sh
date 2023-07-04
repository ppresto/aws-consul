#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Setup local AWS Env variables
if [[ -z $1 ]]; then  #Pass path for tfstate dir if not in quickstart.
output=$(terraform output -state $SCRIPT_DIR/../quickstart/terraform.tfstate -json)
else
output=$(terraform output -state ${1}/terraform.tfstate -json)
fi
AllPublicEndpoints=($(echo $output | jq -r '. | to_entries[] | select(.key|endswith("_consul_public_endpoint_url")) | .value.value'))

export CONSUL_HTTP_ADDR=$(echo $output | jq -r '.use1_consul_public_endpoint_url.value')
export CONSUL_HTTP_TOKEN=$(echo $output | jq -r '.use1_consul_root_token_secret_id.value')

env | grep CONSUL_HTTP

# Stream Server logs (random server behind LB chosen)
# consul monitor -log-level=trace

# Connect CA is 3 day default in Envoy
# curl -s ${CONSUL_HTTP_ADDR}/v1/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -text -noout

# consul peering generate-token -partition=eastus-shared -name=consul1-westus2 -server-external-addresses=1.2.3.4:8502 -token "${CONSUL_HTTP_TOKEN}"
# consul peering delete -name=presto-cluster-use1 -token "${CONSUL_HTTP_TOKEN}"

# curl -sk --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
#   --request DELETE ${CONSUL_HTTP_ADDR}/v1/peering/presto-cluster-use1