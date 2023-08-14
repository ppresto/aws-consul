#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CTX1=api1
CTX2=web1

deploy() {
    kubectl config use-context ${CTX1}
    # deploy api services
    kubectl apply -f ${SCRIPT_DIR}/fake-service/api/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/fake-service/api/
    # Configure Terminating GW for example.com
    ${SCRIPT_DIR}/terminating-gw-example.com/setup-tgw-k8s-crd.sh

    # deploy web services
    kubectl config use-context ${CTX2}
    kubectl create ns api
    kubectl create ns web
    kubectl apply -f ${SCRIPT_DIR}/fake-service/web/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/fake-service/web
    kubectl apply -f ${SCRIPT_DIR}/fake-service/web-final

    # Output Ingress URL for fake-service
    kubectl config use-context ${CTX2}
    echo
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
}

delete() {
    
    kubectl config use-context ${CTX1}
    kubectl delete -f ${SCRIPT_DIR}/fake-service/api
    kubectl delete -f ${SCRIPT_DIR}/fake-service/api/init-consul-config
    ${SCRIPT_DIR}/terminating-gw-example.com/setup-tgw-k8s-crd.sh -d

    kubectl config use-context ${CTX2}
    #kubectl delete -f ${SCRIPT_DIR}/fake-service/web
    kubectl delete -f ${SCRIPT_DIR}/fake-service/web
    kubectl delete -f ${SCRIPT_DIR}/fake-service/web/init-consul-config
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