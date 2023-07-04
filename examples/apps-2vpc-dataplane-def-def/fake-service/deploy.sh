#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

deploy() {
    # deploy westus2 services
    kubectl config use-context app2
    kubectl apply -f ${SCRIPT_DIR}/vpc-api/init-consul-config/intentions-api.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-api/init-consul-config/proxydefaults.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-api/init-consul-config/servicedefaults.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-api/init-consul-config/api_exportedServices.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-api

    kubectl config use-context app1
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/init-consul-config/intentions-web.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/init-consul-config/proxydefaults.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/init-consul-config/servicedefaults.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/init-consul-config/ingressGW.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/init-consul-config/web_exportedServices.yaml
    kubectl apply -f ${SCRIPT_DIR}/vpc-web/

    # Output Ingress URL for fake-service
    kubectl config use-context app1
    echo
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
    
}

delete() {    
    kubectl config use-context app1
    kubectl delete -f ${SCRIPT_DIR}/vpc-web/init-consul-config/web_exportedServices.yaml
    kubectl config use-context app2
    kubectl delete -f ${SCRIPT_DIR}/vpc-api/init-consul-config/api_exportedServices.yaml
    
    kubectl delete -f ${SCRIPT_DIR}/vpc-api
    kubectl delete -f ${SCRIPT_DIR}/vpc-api/init-consul-config

    kubectl config use-context app1
    kubectl delete -f ${SCRIPT_DIR}/vpc-web
    kubectl delete -f ${SCRIPT_DIR}/vpc-web/init-consul-config
}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi