#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

Node="payroll-ec2"
Address="10.17.1.112"
Service="payroll"
Namespace="default"
Partition="api"

echo "Using Context: $(kubectl config current-context)"
echo
echo
if [[ -z ${CONSUL_HTTP_TOKEN} ]]; then
	CONSUL_HTTP_TOKEN="$(kubectl -n consul get secret consul-bootstrap-acl-token -o json | jq -r '.data.token'| base64 -d)"
	echo "Setting CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN}"
else
	echo "CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN}"
fi

if [[ -z ${CONSUL_HTTP_ADDR} ]]; then
	CONSUL_HTTP_ADDR="$(kubectl -n consul get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname'):80"
	echo "Setting CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
else
	echo "CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
fi

reg_svc_data() {
cat <<EOF
  {
    "Node": "$Node",
    "Address": "$Address",
    "Partition": "$Partition",
    "Namespace": "$Namespace",
    "NodeMeta": {
      "external-node": "true",
      "external-probe": "true"
    },
    "Service": {
      "ID": "$Service",
      "Service": "$Service",
      "Port": 9091
    }
  }
EOF
}

svc_data() {

  cat <<EOF
{
  "Node": "$Node",
  "Address": "$Address",
  "Partition": "$Partition",
  "Namespace": "$Namespace",
  "ServiceID": "$Service"
}
EOF
}

node_data() {
  cat <<EOF
{
  "Node": "$Node",
  "Address": "$Address",
  "Partition": "$Partition",
  "Namespace": "$Namespace"
}
EOF
}

register_ext_svc() {
  echo "curl --silent --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request PUT --data \"$(reg_svc_data)\" ${CONSUL_HTTP_ADDR}/v1/catalog/register"
	curl --silent --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT --data "$(reg_svc_data)" ${CONSUL_HTTP_ADDR}/v1/catalog/register
}

verify_registration(){
  echo
  echo
  echo "Lookup $Service in the Catalog"
  echo "curl --silent --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" ${CONSUL_HTTP_ADDR}/v1/catalog/service/$Service"
	curl --silent --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/catalog/service/$Service?ap=$Partition | jq -r
}

deregister_ext_svc() {
  echo "Deleting Service $Service"
	curl --silent --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT --data "$(svc_data)"  ${CONSUL_HTTP_ADDR}/v1/catalog/deregister
	echo "curl --silent --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request PUT --data "$(svc_data)"  ${CONSUL_HTTP_ADDR}/v1/catalog/deregister"
  echo
  echo "Deleting Service Node: $Node"
  echo "curl --silent --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request PUT --data '{\"Node\": \"${Node}\",\"Address\": \"${Address}\"}' ${CONSUL_HTTP_ADDR}/v1/catalog/deregister"
	curl --silent --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT --data "$(node_data)" ${CONSUL_HTTP_ADDR}/v1/catalog/deregister
}

#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
	deregister_ext_svc
else
  register_ext_svc
  verify_registration
fi
