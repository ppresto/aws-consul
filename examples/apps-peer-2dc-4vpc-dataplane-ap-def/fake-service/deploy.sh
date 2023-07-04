#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CTX1=app1
CTX2=app2

deploy() {
    # deploy eastus services
    kubectl config use-context ${CTX1}
    kubectl apply -f ${SCRIPT_DIR}/${CTX1}/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/${CTX1}/

    # deploy westus2 services
    kubectl config use-context ${CTX2}
    kubectl apply -f ${SCRIPT_DIR}/${CTX2}/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/${CTX2}

    # Output Ingress URL for fake-service
    kubectl config use-context ${CTX2}
    echo
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
}

delete() {
    kubectl config use-context ${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/${CTX1}/init-consul-config

    kubectl config use-context ${CTX2}
    kubectl delete -f ${SCRIPT_DIR}/${CTX2}
    kubectl delete -f ${SCRIPT_DIR}/${CTX2}/init-consul-config

}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi