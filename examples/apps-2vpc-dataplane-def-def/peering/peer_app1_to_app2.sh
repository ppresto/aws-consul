#!/bin/bash
CUR_SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# PreReq - 
#  Setup Kubeconfig to auth into AKS Consul cluster

function setup () {
  #
  ### East DC: presto-cluster-use1
  #
  kubectl config use-context app1

  # # Verify Peering through MG
  # kubectl -n consul exec -it consul-server-0 -- consul config read -kind mesh -name mesh | grep PeerThroughMeshGateways
  # # Verify MG is in local mode
  # kubectl -n consul exec -it consul-server-0 -- consul config read -kind proxy-defaults -name global
  
  # Create Peering Acceptor
  echo "kubectl apply -f ${CUR_SCRIPT_DIR}/peering-acceptor-east.yaml"
  kubectl apply -f ${CUR_SCRIPT_DIR}/peering-acceptor-east.yaml

  # Verify Peering Acceptor and Secret was created
  kubectl -n consul get peeringacceptors
  kubectl -n consul get secret peering-token-app2-default --template "{{.data.data | base64decode | base64decode }}" | jq

  #
  ### West DC: presto-cluster-usw2
  #

  # Copy secrets from peering acceptor (East) to peering dialer (West)
  kubectl -n consul get secret peering-token-app2-default --context app1 -o yaml | kubectl apply --context app2 -f -

  # Create Peering Dialer
  kubectl config use-context app2
  kubectl apply -f ${CUR_SCRIPT_DIR}/peering-dialer-west.yaml

  # Verify peering from the Acceptor
  #kubectl config use-context app1
  echo
  echo "Verifying Peering Connection on Acceptor (EAST) with curl command:"
  sleep 5
  # GET CONSUL ENV Values (CONSUL_HTTP_TOKEN, CONSUL_HTTP_ADDR)
  CONSUL_HTTP_TOKEN=$(kubectl -n consul --context=consul1 get secrets consul-bootstrap-acl-token --template "{{ .data.token | base64decode }}")
  CONSUL_HTTP_ADDR=$(kubectl -n consul --context=consul1 get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname')
  curl -sk --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    --request GET ${CONSUL_HTTP_ADDR}/v1/peering/app2-default \
    | jq -r

  echo "curl -sk --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request GET ${CONSUL_HTTP_ADDR}/v1/peering/app2-default | jq -r"

  # Export Services for each peer to advertise available service catalog.
  echo "Exporting Acceptor services..."
  kubectl config use-context app1
  kubectl apply -f ${CUR_SCRIPT_DIR}/exportedServices_app1-default.yaml
  echo "Exporting Dialer services..."
  kubectl config use-context app2
  kubectl apply -f ${CUR_SCRIPT_DIR}/exportedServices_app2-default.yaml
}

# Clean up
function remove () {
    kubectl config use-context app2
    #kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_presto-cluster-usw2-default.yaml
    kubectl delete -f ${CUR_SCRIPT_DIR}/peering-dialer-west.yaml
    kubectl -n consul delete secret peering-token-app2-default
    kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_app2-default.yaml

    kubectl config use-context app1
    kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_app1-default.yaml
    kubectl delete -f ${CUR_SCRIPT_DIR}/peering-acceptor-east.yaml
}

if [[ -z $1 ]]; then
  setup
else
  remove
fi