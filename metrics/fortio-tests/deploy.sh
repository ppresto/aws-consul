#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# fortio deploy uses nodeselector (nodegroup=services) to isolate testing services.  Verify if this label isn't being used
# to isolate workloads and apply a patch to create "nodegroup=default" if needed and patch service deployments to use it.
checkNodeLabels(){
    label=""
    nodes=$(kubectl get nodes -o json | jq -r '.items[].metadata.labels."kubernetes.io/hostname"')
    for node in ${nodes}
    do
        test=$(kubectl get nodes $node --show-labels | grep -w "nodegroup=services")
        if [[ $test != "" ]]; then
            echo "Label Found. Deploying to nodeselector 'nodegroup=services'"
            label="exists"
            break
        fi
    done

    if [[ $label != "exists" ]]; then
        for node in ${nodes}
        do
            test=$(kubectl get nodes $node --show-labels | grep -w "nodegroup=default")
            if [[ $test != "" ]]; then
                kubectl label nodes $node nodegroup=default
            fi
        done
        export PATCH=true  #disable nodeselector
    fi
}
patch() {
    if [[ $PATCH == true ]]; then
        kubectl -n fortio-baseline patch deployment fortio-client --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-baseline patch deployment fortio-server-defaults --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"

        kubectl -n fortio-consul-default patch deployment fortio-client --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-default patch deployment fortio-server-defaults --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-default patch deployment fortio-server-defaults-grpc --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"

        kubectl -n fortio-consul-optimized patch deployment fortio-client --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-optimized patch deployment fortio-server-defaults --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-optimized patch deployment fortio-server-defaults-grpc --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"

        kubectl -n fortio-consul-logs patch deployment fortio-client --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-logs patch deployment fortio-server-defaults --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-logs patch deployment fortio-server-defaults-grpc --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"

        kubectl -n fortio-consul-l7 patch deployment fortio-client --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-l7 patch deployment fortio-server-defaults --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-consul-l7 patch deployment fortio-server-defaults-grpc --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
    fi
}
deploy() {
    #kubectl config use-context usw2-app1
    kubectl create namespace fortio-baseline
    kubectl create namespace fortio-consul-default
    kubectl create namespace fortio-consul-optimized
    kubectl create namespace fortio-consul-logs
    kubectl create namespace fortio-consul-l7
    kubectl create namespace fortio-consul-tcp

    kubectl apply -f ${SCRIPT_DIR}/baseline
    kubectl apply -f ${SCRIPT_DIR}/consul-default/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/consul-default
    kubectl apply -f ${SCRIPT_DIR}/consul-tcp/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/consul-tcp
    kubectl apply -f ${SCRIPT_DIR}/consul-optimized/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/consul-optimized
    kubectl apply -f ${SCRIPT_DIR}/consul-logs/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/consul-logs
    kubectl apply -f ${SCRIPT_DIR}/consul-l7/init-consul-config
    kubectl apply -f ${SCRIPT_DIR}/consul-l7

    echo 
    echo "grafana"
    echo "http://$(kubectl -n metrics get svc -l app.kubernetes.io/name=grafana -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):3000"
    # Output Ingress URL for fortio
    echo
    echo "fortio"
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):8080/fortio"
    echo
}

delete() {
    #kubectl config use-context usw2-app1
    kubectl delete -f ${SCRIPT_DIR}/consul-default
    kubectl delete -f ${SCRIPT_DIR}/consul-default/init-consul-config
    kubectl delete -f ${SCRIPT_DIR}/consul-logs
    kubectl delete -f ${SCRIPT_DIR}/consul-logs/init-consul-config
    kubectl delete -f ${SCRIPT_DIR}/consul-optimized
    kubectl delete -f ${SCRIPT_DIR}/consul-optimized/init-consul-config
    kubectl delete -f ${SCRIPT_DIR}/baseline
    kubectl delete -f ${SCRIPT_DIR}/consul-l7
    kubectl delete -f ${SCRIPT_DIR}/consul-l7/init-consul-config
    kubectl delete -f ${SCRIPT_DIR}/consul-tcp
    kubectl delete -f ${SCRIPT_DIR}/consul-tcp/init-consul-config
    
    kubectl delete namespace fortio-consul-optimized
    kubectl delete namespace fortio-consul-default
    kubectl delete namespace fortio-consul-logs
    kubectl delete namespace fortio-consul-l7
    kubectl delete namespace fortio-consul-tcp
    kubectl delete namespace fortio-baseline
}

#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
    checkNodeLabels
    patch
    echo
    echo "Waiting for fortio client pod to be ready..."
    echo
    kubectl -n fortio-consul-default wait --for=condition=ready pod -l app=fortio-client
    echo
fi
