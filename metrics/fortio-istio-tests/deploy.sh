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

        kubectl -n fortio-istio-default patch deployment fortio-client --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-istio-default patch deployment fortio-server-defaults --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
        kubectl -n fortio-istio-default patch deployment fortio-server-defaults-grpc --patch "$(cat ${SCRIPT_DIR}/default-nodeselector-patch.yaml)"
    fi
}
deploy() {
    #kubectl config use-context usw2-app1
    #kubectl create namespace fortio-baseline
    kubectl create namespace fortio-istio-default
    kubectl create namespace fortio-istio-tcp

    kubectl label namespace fortio-istio-default istio-injection=enabled
    kubectl label namespace fortio-istio-tcp istio-injection=enabled

    #kubectl apply -f ${SCRIPT_DIR}/baseline
    kubectl apply -f ${SCRIPT_DIR}/istio-default/init-istio-config
    kubectl apply -f ${SCRIPT_DIR}/istio-default
    kubectl apply -f ${SCRIPT_DIR}/istio-tcp/init-istio-config
    kubectl apply -f ${SCRIPT_DIR}/istio-tcp
    # container env used in fortiocli.sh to call Prometheus API.
    kubectl create namespace consul
    kubectl apply -f ${SCRIPT_DIR}/../../examples/consul-cli/consulcli.yaml
}

delete() {
    #kubectl config use-context usw2-app1

    kubectl delete -f ${SCRIPT_DIR}/istio-default/init-istio-config
    kubectl delete -f ${SCRIPT_DIR}/istio-default
    kubectl delete -f ${SCRIPT_DIR}/istio-tcp/init-istio-config
    kubectl delete -f ${SCRIPT_DIR}/istio-tcp
    #kubectl delete -f ${SCRIPT_DIR}/baseline

    kubectl delete namespace fortio-istio-default
    kubectl delete namespace fortio-istio-tcp
    #kubectl delete namespace fortio-baseline
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
    kubectl -n fortio-istio-default wait --for=condition=ready pod -l app=fortio-client
    echo
fi
