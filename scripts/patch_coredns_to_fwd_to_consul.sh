#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CORE_DNS_TMPL_DIR="${SCRIPT_DIR}/../quickstart/templates/coredns"
CONSUL_DNS_SVC="consul-dns"
echo "Patching coredns in k8s_context: $(kubectl config current-context)"
echo "Using template from: ${CORE_DNS_TMPL_DIR}"
echo
CONSUL_DNS_CLUSTER_IP=$(kubectl -n consul get svc ${CONSUL_DNS_SVC} -o json | jq -r '.spec.clusterIP')
sed "s/\${CONSUL_DNS_CLUSTER_IP}/$CONSUL_DNS_CLUSTER_IP/g" ${CORE_DNS_TMPL_DIR}/coredns-patch.yaml > ${CORE_DNS_TMPL_DIR}/patch.yaml
kubectl -n kube-system patch configmap/coredns --type merge --patch-file ${CORE_DNS_TMPL_DIR}/patch.yaml

rm ${CORE_DNS_TMPL_DIR}/patch.yaml
kubectl -n kube-system delete po -l k8s-app=kube-dns