#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

deploy() {
    # deploy eastus services
    kubectl config use-context use1-app1
    kubectl apply -f ${SCRIPT_DIR}/eastus/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/eastus/release-api

    # deploy westus2 services
    kubectl config use-context usw2-app1
    kubectl apply -f ${SCRIPT_DIR}/westus2/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/westus2/api.yaml
    kubectl apply -f ${SCRIPT_DIR}/westus2/web.yaml.static-upstream


    # Output Ingress URL for fake-service
    echo
    echo "Region: US-West-2"
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/ui"
    echo
    
}

delete() {
    kubectl config use-context use1-app1
    kubectl delete -f ${SCRIPT_DIR}/eastus/release-api
    kubectl delete -f ${SCRIPT_DIR}/eastus/init-consul-config
    kubectl config use-context usw2-app1
    kubectl delete -f ${SCRIPT_DIR}/westus2/web.yaml.static-upstream
    kubectl delete -f ${SCRIPT_DIR}/westus2/api.yaml
    kubectl delete -f ${SCRIPT_DIR}/westus2/init-consul-config

}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi