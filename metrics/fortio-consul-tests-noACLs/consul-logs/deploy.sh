#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
nodeSelector="--set nodeSelector.nodegroup=default"

deploy() {
    # deploy eastus services
    kubectl config use-context usw2-app1
    kubectl create namespace fortio-consul-logs
    kubectl apply -f ${SCRIPT_DIR}/init-consul-config 
    kubectl apply -f ${SCRIPT_DIR}/.

    echo 
    echo "grafana"
    echo "http://$(kubectl -n metrics get svc -l app.kubernetes.io/name=grafana -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):3000"
    # Output Ingress URL for fortio
    echo
    echo "To Run Load Test - port-forward fortio client with this command"
    echo "kc -n fortio-consul-logs port-forward deploy/fortio-client 8080:8080"
    echo
    echo "http://localhost:8080/fortio"
}

delete() {
    kubectl config use-context usw2-app1
    kubectl delete -f ${SCRIPT_DIR}/.
    kubectl delete -f ${SCRIPT_DIR}/init-consul-config
    kubectl delete namespace fortio-consul-logs
}

#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi
