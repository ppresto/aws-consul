#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CTX1=web1

deploy() {
    # Output Ingress URL for fake-service
    kubectl config use-context ${CTX1}
    kubectl apply -f ${SCRIPT_DIR}/
    kubectl -n consul delete po -l component=mesh-gateway  # delete mgw to reconfigure
    echo
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
}

delete() {
    kubectl config use-context ${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/
}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi