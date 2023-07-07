#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Setup local AWS Env variables
if [[ $1 ]]; then  #Pass path for tfstate dir if not in quickstart.
output=$(terraform output -state ${1}/terraform.tfstate -json)
else
    echo "provide path to tf state file"
    exit 1
fi
PROJECTS=($(echo $output | jq -r '. | to_entries[] | select(.key|endswith("_projects")) | .value.value[]'))

# Download
# curl -L https://istio.io/downloadIstio | sh -
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.18.0 TARGET_ARCH=x86_64 sh -
export PATH=${SCRIPT_DIR}/istio-1.18.0/bin:$PATH

# Install
istioctl x precheck
#istioctl install --set profile=demo -y
istioctl install --set profile=minimal -y
kubectl label namespace default istio-injection=enabled
