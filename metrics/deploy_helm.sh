#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

nodeSelector="--set nodeSelector.nodegroup=default"
# Target Metrics deployment to nodeSelector 'nodegroup=default'
# If No nodes have the label 'nodegroup=default' then set this for all nodes.
fixNodeLabels(){
    label=""
    nodes=$(kubectl get nodes -o json | jq -r '.items[].metadata.labels."kubernetes.io/hostname"')
    for node in ${nodes}
    do
        test=$(kubectl get nodes $node --show-labels | grep -w "nodegroup=default")
        if [[ $test != "" ]]; then
            echo "Label Found. Not Creating labels"
            label="exists"
            break
        fi
    done

    if [[ $label != "exists" ]]; then
        for node in ${nodes}
        do
            echo "Creating Lable: nodegroup=default"
            kubectl label nodes $node nodegroup=default
        done
    fi
}

helmDeploy() {
    kubectl create namespace metrics
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install -n metrics -f ${SCRIPT_DIR}/helm/prometheus-values-with-nodeselector.yaml prometheus prometheus-community/prometheus --version "15.5.3" --wait
    # Set Consul Server for prometheus-consul-exporter
    sed "s/{{CONSUL_SERVER}}/${CONSUL_SERVER}/" ${SCRIPT_DIR}/helm/prometheus-consul-exporter.yaml.tmpl > ${SCRIPT_DIR}/helm/prometheus-consul-exporter.yaml
    helm install -n metrics -f ${SCRIPT_DIR}/helm/prometheus-consul-exporter.yaml prometheus-consul-exporter prometheus-community/prometheus-consul-exporter ${nodeSelector} --wait

    helm repo add grafana https://grafana.github.io/helm-charts
    helm install -n metrics -f ${SCRIPT_DIR}/helm/grafana-values-with-lb.yaml grafana grafana/grafana ${nodeSelector} --wait

    # Consul dataplane should already be installed in the consul ns.  Deploying consulcli to this ns for sh,time,curl,jq to pull from Prometheus API.
    kubectl apply -f ${SCRIPT_DIR}/../examples/consul-cli/consulcli.yaml
}

helmUndeploy() {
    helm uninstall -n metrics prometheus 
    helm uninstall -n metrics prometheus-consul-exporter
    helm uninstall -n metrics grafana
    kubectl delete ns metrics
    kubectl delete -f ${SCRIPT_DIR}/../examples/consul-cli/consulcli.yaml
}

usage() { 
    echo "Usage: $0 [-d] #Delete / Undeploy all helm charts" 1>&2; 
    echo "Example: $0 -d"
    echo
    echo "Usage: $0 -c [CONSUL_SERVER:PORT]" 1>&2; 
    echo
    echo "Example: $0 -c consul-server:8500"
    exit 1; 
}

while getopts "dc:" o; do
    case "${o}" in
        d)
            echo "Deleting Helm deployments"
            helmUndeploy
            exit
            ;;
        c)
            CONSUL_SERVER="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Set consul server to default value if not specified.  Required for prometheus-consul-exporter helm value
if [[ -z $CONSUL_SERVER ]]; then
    CONSUL_SERVER="consul-server:8500"
    echo "Setting CONSUL_SERVER to $CONSUL_SERVER"
else
    CONSUL_SERVER="${CONSUL_SERVER#https://}:443"
    echo "Setting CONSUL_SERVER to $CONSUL_SERVER"
fi

echo "Installing Observability Stack"
fixNodeLabels
helmDeploy $CONSUL_SERVER
sleep 3
kubectl get pods
echo 
echo "grafana"
echo "http://$(kubectl -n metrics get svc -l app.kubernetes.io/name=grafana -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'):3000"
echo