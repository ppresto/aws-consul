#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CTX1=consul1
CTX2=consul2
deploy() {
    kubectl config use-context ${CTX1}
    kubectl apply -f ${SCRIPT_DIR}/dc1/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/dc1/
    
    # deploy westus2 services
    kubectl config use-context ${CTX2}
    kubectl apply -f ${SCRIPT_DIR}/dc2/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/dc2/
    

    # Output Ingress URL for fake-service
    echo
    echo "$(kubectl config current-context)"
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo

    kubectl config use-context ${CTX1}
    echo
    echo "$(kubectl config current-context)"
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
}

delete() {
    kubectl config use-context ${CTX2}
    kubectl delete -f ${SCRIPT_DIR}/dc2/
    kubectl delete -f ${SCRIPT_DIR}/dc2/init-consul-config

    kubectl config use-context ${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/dc1/
    kubectl delete -f ${SCRIPT_DIR}/dc1/init-consul-config
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
