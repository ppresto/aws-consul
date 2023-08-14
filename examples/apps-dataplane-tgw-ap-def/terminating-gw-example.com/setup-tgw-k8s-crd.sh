#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
#CTX1="api1"  #K8s Context
Namespace="default"
Partition="api"
Node="payroll-ec2"
Address="10.17.1.112"
Service="example-https"


#kubectl config use-context ${CTX1}
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

svc_acl() {
  cat <<EOF
service "$Service" {
  policy = "write"
}
EOF
}

setup_terminating_gw() {
  echo "update service defaults with $Service"
  kubectl apply -f ${SCRIPT_DIR}/servicedefaults.yaml
  echo
  echo "Update Terminating GW with write perms to $Service"

  # Create new ACL Policy with service write permissions
  consul acl policy create -name "terminating-gateway-${Service}-policy" -rules "$(svc_acl)" -partition ${Partition} -namespace ${Namespace}

  # Get Terminating GW role ID (ROLE_ID)
  ROLE_ID=$(consul acl role list -partition ${Partition} -namespace ${Namespace} | grep -B 6 -- "terminating-gateway-policy" | grep ID| awk '{print $NF}')
  echo "Getting Terminationg GW Role ID: $ROLE_ID"
  # Update Terminating GW Role (ROLE_ID) with the new ACL Policy
  consul acl role update -id ${ROLE_ID} -partition ${Partition} -namespace ${Namespace} -policy-name "terminating-gateway-${Service}-policy"

  # Apply Terminating GW CRD with the new service defined
  kubectl apply -f ${SCRIPT_DIR}/terminating-gw.yaml

  # Create Intentions
  kubectl apply -f ${SCRIPT_DIR}/intentions.yaml
}

delete() {
  kubectl delete -f ${SCRIPT_DIR}/terminating-gw.yaml
  kubectl delete -f ${SCRIPT_DIR}/intentions.yaml
  kubectl delete -f ${SCRIPT_DIR}/servicedefaults.yaml
  consul acl policy delete -partition ${Partition} -namespace ${Namespace} -name "terminating-gateway-${Service}-policy"
}

#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
	delete
else
  setup_terminating_gw
fi
