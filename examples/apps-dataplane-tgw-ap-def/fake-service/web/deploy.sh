#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CTX1=web1

deploy() {
    kubectl config use-context ${CTX1}
    kubectl create ns api
    kubectl create ns web
    kubectl apply -f ${SCRIPT_DIR}/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/

    # Output Ingress URL for fake-service
    kubectl config use-context ${CTX1}
    echo
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
}

delete() {
    
    kubectl config use-context ${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/
    kubectl delete -f ${SCRIPT_DIR}/init-consul-config
    kubectl delete ns api
    kubectl delete ns web
}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi