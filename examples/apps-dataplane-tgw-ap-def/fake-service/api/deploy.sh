#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CTX1=api1

deploy() {
    kubectl config use-context ${CTX1}
    # deploy api services
    kubectl apply -f ${SCRIPT_DIR}/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/

    # Configure Terminating GW for example.com
    ${SCRIPT_DIR}/../../terminating-gw-example.com/setup-tgw-k8s-crd.sh
}

delete() {
    
    kubectl config use-context ${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/
    kubectl delete -f ${SCRIPT_DIR}/init-consul-config
    ${SCRIPT_DIR}/../../terminating-gw-example.com/setup-tgw-k8s-crd.sh -d
}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi