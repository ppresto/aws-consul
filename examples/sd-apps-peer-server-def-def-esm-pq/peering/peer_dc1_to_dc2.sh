#!/bin/bash
CUR_SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# PreReq - 
#  Setup Kubeconfig to auth into AKS Consul cluster
CTX1=consul1
CTX2=consul2
function setup () {
  #
  ### East DC: presto-cluster-use1
  #
  kubectl config use-context ${CTX1}

  # # Verify Peering through MG
  # kubectl -n consul exec -it consul-server-0 -- consul config read -kind mesh -name mesh | grep PeerThroughMeshGateways
  # # Verify MG is in local mode
  # kubectl -n consul exec -it consul-server-0 -- consul config read -kind proxy-defaults -name global
  
  # Create Peering Acceptor
  echo "kubectl apply -f ${CUR_SCRIPT_DIR}/peering-acceptor-dc1.yaml"
  kubectl apply -f ${CUR_SCRIPT_DIR}/peering-acceptor-dc1.yaml

  # Verify Peering Acceptor and Secret was created
  kubectl -n consul get peeringacceptors
  kubectl -n consul get secret peering-token-dc2-default --template "{{.data.data | base64decode | base64decode }}" | jq

  #
  ### West DC: presto-cluster-usw2
  #

  # Copy secrets from peering acceptor (East) to peering dialer (West)
  kubectl -n consul get secret peering-token-dc2-default --context ${CTX1} -o yaml | kubectl apply --context ${CTX2} -f -

  # Create Peering Dialer
  kubectl apply --context ${CTX2} -f ${CUR_SCRIPT_DIR}/peering-dialer-dc2.yaml

  # Verify peering from the Acceptor
  #kubectl config use-context ${CTX1}
  echo
  echo "Verifying Peering Connection on Acceptor (DC1) with curl command:"
  sleep 5
  # GET CONSUL ENV Values (CONSUL_HTTP_TOKEN, CONSUL_HTTP_ADDR)
  source ${CUR_SCRIPT_DIR}/../../../scripts/setConsulEnv.sh
  #source ${CUR_SCRIPT_DIR}/../../../scripts/setHCP-ConsulEnv-use1.sh ${CUR_SCRIPT_DIR}/../../../quickstart/2hcp-2eks-2ec2/
  curl -sk --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    --request GET ${CONSUL_HTTP_ADDR}/v1/peering/dc2-default \
    | jq -r

  echo "curl -sk --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request GET ${CONSUL_HTTP_ADDR}/v1/peering/dc2-default | jq -r"

  # Export Services for each peer to advertise available service catalog.
  echo "Exporting Acceptor services..."
  kubectl apply --context ${CTX1} -f ${CUR_SCRIPT_DIR}/exportedServices_dc1-default.yaml
  echo "Exporting Dialer services..."
  kubectl apply --context ${CTX2}  -f ${CUR_SCRIPT_DIR}/exportedServices_dc2-default.yaml
}

# Clean up
function remove () {
    kubectl config use-context ${CTX2}
    kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_dc2-default.yaml
    kubectl delete -f ${CUR_SCRIPT_DIR}/peering-dialer-dc2.yaml
    kubectl -n consul delete secret peering-token-dc2-default

    kubectl config use-context ${CTX1}
    kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_dc1-default.yaml
    kubectl delete -f ${CUR_SCRIPT_DIR}/peering-acceptor-dc1.yaml
}

if [[ -z $1 ]]; then
  setup
else
  remove
fi