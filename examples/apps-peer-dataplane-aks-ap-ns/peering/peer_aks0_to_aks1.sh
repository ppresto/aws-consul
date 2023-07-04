#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# PreReq - 
#  Setup Kubeconfig to auth into AKS Consul cluster

function setup () {
  #kubectl config use-context aks0
  kubectl config use-context aks0

  # Verify Peering through MG
  #kubectl -n consul exec -it consul-server-0 -- consul config read -kind mesh -name mesh | grep PeerThroughMeshGateways
  # Verify MG is in local mode
  #kubectl -n consul exec -it consul-server-0 -- consul config read -kind proxy-defaults -name global
  
  # Create Peering Acceptor (aks0)
  echo "kubectl apply -f ${SCRIPT_DIR}/peering-acceptor-aks0.yaml"
  kubectl apply -f ${SCRIPT_DIR}/peering-acceptor-aks0.yaml

  # Verify Peering Acceptor and Secret was created
  kubectl -n consul get peeringacceptors
  kubectl -n consul get secret peering-token-aks1-westus2 --template "{{.data.data | base64decode | base64decode }}" | jq

  # Copy secrets from peering acceptor (aks0) to peering dialer (aks1)
  kubectl -n consul get secret peering-token-aks1-westus2 --context aks0 -o yaml | kubectl apply --context aks1 -f -

  # Create Peering Dialer (aks1)
  kubectl config use-context aks1
  echo "kubectl apply -f ${SCRIPT_DIR}/peering-dialer-aks1.yaml"
  kubectl apply -f ${SCRIPT_DIR}/peering-dialer-aks1.yaml

  # Verify peering on aks0
  kubectl config use-context consul0
  echo
  echo "Verifying Peering Connection on Acceptor with curl command:"
  sleep 5
  CONSUL_HTTP_TOKEN=$(kubectl -n consul get secrets consul-bootstrap-acl-token -o go-template --template="{{.data.token|base64decode}}")
  echo "kubectl -n consul exec -it consul-server-0 -- curl -k --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request GET https://localhost:8501/v1/peering/westus2-shared?partition=eastus-shared"
  kubectl -n consul exec -it consul-server-0 -- curl -k \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --request GET \
      https://localhost:8501/v1/peering/westus2-shared?partition=eastus-shared \
      | jq -r

  # Export Services for each peer to advertise available service catalog.
  echo "Exporting Acceptor services..."
  kubectl config use-context aks0
  kubectl apply -f ${SCRIPT_DIR}/exportedServices_aks0-eastus.yaml
  echo "Exporting Dialer services..."
  kubectl config use-context aks1
  kubectl apply -f ${SCRIPT_DIR}/exportedServices_aks1-westus2.yaml
}

# Clean up
function remove () {
    kubectl config use-context aks1
    kubectl delete -f ${SCRIPT_DIR}/exportedServices_aks1-westus2.yaml
    kubectl delete -f ${SCRIPT_DIR}/peering-dialer-aks1.yaml
    kubectl -n consul delete secret peering-token-aks1-westus2

    kubectl config use-context aks0
    kubectl delete -f ${SCRIPT_DIR}/exportedServices_aks0-eastus.yaml
    kubectl delete -f ${SCRIPT_DIR}/peering-acceptor-aks0.yaml
}

if [[ -z $1 ]]; then
  setup
else
  remove
fi