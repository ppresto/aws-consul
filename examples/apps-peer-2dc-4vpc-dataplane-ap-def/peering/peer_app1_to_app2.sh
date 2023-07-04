#!/bin/bash
CUR_SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# PreReq - 
#  Setup Kubeconfig to auth into AKS Consul cluster

# Setup Env
function meshDefaultsAPI () {
  source ${CUR_SCRIPT_DIR}/../../../scripts/setHCP-ConsulEnv-use1.sh ${CUR_SCRIPT_DIR}/../../../quickstart/2hcp-2eks-2ec2-hvnpeering/
# Configure Mesh defaults
  cat >/tmp/mesh-usw2.json <<-EOF
{
  "Kind": "mesh",
  "Namespace": "default",
  "Partition": "default",
  "Peering": {
    "PeerThroughMeshGateways": true
  },
  "Meta": {
        "consul.hashicorp.com/source-datacenter": "presto-cluster-usw2",
        "external-source": "kubernetes"
  },
  "TransparentProxy": {
    "MeshDestinationsOnly": false
  }
}
EOF

  curl --request PUT --data @/tmp/mesh-usw2.json --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/config
  # Read Configuration
  curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/config/mesh/mesh | jq -r
 
 source ${CUR_SCRIPT_DIR}/../../../scripts/setHCP-ConsulEnv-use1.sh ${CUR_SCRIPT_DIR}/../../../quickstart/2hcp-2eks-2ec2-hvnpeering/
# Configure Mesh defaults
  cat >/tmp/mesh-use1.json <<-EOF
{
  "Kind": "mesh",
  "Namespace": "default",
  "Partition": "default",
  "Peering": {
    "PeerThroughMeshGateways": true
  },
  "Meta": {
        "consul.hashicorp.com/source-datacenter": "presto-cluster-use1",
        "external-source": "kubernetes"
  },
  "TransparentProxy": {
    "MeshDestinationsOnly": false
  }
}
EOF

  curl --request PUT --data @/tmp/mesh-use1.json --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/config
  # Read Configuration
  curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/config/mesh/mesh | jq -r
  
}

function meshDefaults () {
  kubectl config use-context consul1
  kubectl apply -f mesh.yaml
  kubectl config use-context consul2
  kubectl apply -f mesh.yaml
}
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
  echo "kubectl apply -f ${CUR_SCRIPT_DIR}/peering-acceptor-app1.yaml"
  kubectl apply -f ${CUR_SCRIPT_DIR}/peering-acceptor-app1.yaml

  # Verify Peering Acceptor and Secret was created
  kubectl -n consul get peeringacceptors
  kubectl -n consul get secret peering-token-dc1-app1 --template "{{.data.data | base64decode | base64decode }}" | jq

  #
  ### West DC: presto-cluster-usw2
  #

  # Copy secrets from peering acceptor (App1) to peering dialer (App2)
  kubectl -n consul get secret peering-token-dc1-app1 --context app1 -o yaml | kubectl apply --context app2 -f -

  # Create Peering Dialer
  kubectl config use-context app2
  kubectl apply -f ${CUR_SCRIPT_DIR}/peering-dialer-app2.yaml

  # Verify peering from the Acceptor
  #kubectl config use-context app1
  echo
  echo "Verifying Peering Connection"
  echo " Acceptor datacenter: dc1 (--context=consul1)"
  echo " Acceptor Partition:  app1"
  echo " Acceptor Peering to: dc2-app2"
  sleep 5
  # GET CONSUL ENV Values (CONSUL_HTTP_TOKEN, CONSUL_HTTP_ADDR)
  CONSUL_HTTP_ADDR="https://$(kubectl -n consul --context=consul1 get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname')"
  CONSUL_HTTP_TOKEN="$(kubectl -n consul --context=consul1 get secrets consul-bootstrap-acl-token --template "{{ .data.token | base64decode }}")"
  curl -sk --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    --request GET ${CONSUL_HTTP_ADDR}/v1/peering/dc2-app2?partition=app1 \
    | jq -r

  echo "curl -sk --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request GET ${CONSUL_HTTP_ADDR}/v1/peering/dc1-app1?partition=app1 | jq -r"

  # Export Services for each peer to advertise available service catalog.
  # echo "Exporting Acceptor services..."
  # kubectl config use-context app1
  # kubectl apply -f ${CUR_SCRIPT_DIR}/exportedServices_dc1-app1.yaml
  #echo "Exporting Dialer services..."
  #kubectl config use-context consul1
  #kubectl apply -f ${CUR_SCRIPT_DIR}/exportedServices_consul1-westus2.yaml
}

# Clean up
function remove () {
    kubectl config use-context app2
    #kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_presto-cluster-usw2-default.yaml
    kubectl delete -f ${CUR_SCRIPT_DIR}/peering-dialer-app2.yaml
    kubectl -n consul delete secret peering-token-dc1-app1

    kubectl config use-context app1
    #kubectl delete -f ${CUR_SCRIPT_DIR}/exportedServices_dc1-app1.yaml
    kubectl delete -f ${CUR_SCRIPT_DIR}/peering-acceptor-app1.yaml

    kubectl config use-context consul1
    kubectl delete -f mesh.yaml
    kubectl config use-context consul2
    kubectl delete -f mesh.yaml
}

if [[ -z $1 ]]; then
  meshDefaults
  setup
else
  remove
fi