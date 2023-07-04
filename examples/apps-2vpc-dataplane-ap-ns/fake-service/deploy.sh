#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

deploy() {
    # deploy westus2 services
    kubectl config use-context api
    kubectl create namespace api
    kubectl apply -f ${SCRIPT_DIR}/vpc-api/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/vpc-api

    kubectl config use-context web
    kubectl create namespace web
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/

    # Output Ingress URL for fake-service
    kubectl config use-context web
    echo
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
    
}

delete() {    
    kubectl config use-context web
    kubectl delete -f ${SCRIPT_DIR}/vpc-web/init-consul-config/web_exportedServices.yaml
    kubectl config use-context api
    kubectl delete -f ${SCRIPT_DIR}/vpc-api/init-consul-config/api_exportedServices.yaml
    
    kubectl delete -f ${SCRIPT_DIR}/vpc-api
    kubectl delete -f ${SCRIPT_DIR}/vpc-api/init-consul-config
    kubectl delete namespace api

    kubectl config use-context web
    kubectl delete -f ${SCRIPT_DIR}/vpc-web
    kubectl delete -f ${SCRIPT_DIR}/vpc-web/init-consul-config
    kubectl delete namespace web

}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi