#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

deploy() {
    kubectl config use-context use1-app1
    kubectl apply -f ${SCRIPT_DIR}/eastus/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/eastus/
    
    # deploy westus2 services
    kubectl config use-context usw2-app1
    kubectl apply -f ${SCRIPT_DIR}/westus2/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/westus2/
    

    # Output Ingress URL for us-west-2 fake-service
    echo
    echo "Region: us-west-2"
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
}

delete() {
    kubectl config use-context usw2-app1
    kubectl delete -f ${SCRIPT_DIR}/westus2/
    kubectl delete -f ${SCRIPT_DIR}/westus2/init-consul-config

    kubectl config use-context use1-app1
    kubectl delete -f ${SCRIPT_DIR}/eastus/
    kubectl delete -f ${SCRIPT_DIR}/eastus/init-consul-config
}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi

# API service Observability
# curl -sk --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}"     --request GET ${CONSUL_HTTP_ADDR}/v1/health/service/api?partition=test | jq -r
