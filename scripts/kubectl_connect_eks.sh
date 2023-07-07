#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Setup local AWS Env variables
if [[ -z $1 ]]; then  #Pass path for tfstate dir if not in quickstart.
output=$(terraform output -state $SCRIPT_DIR/../quickstart/terraform.tfstate -json)
else
output=$(terraform output -state ${1}/terraform.tfstate -json)
fi
PROJECTS=($(echo $output | jq -r '. | to_entries[] | select(.key|endswith("_projects")) | .value.value[]'))

# Authenticate to EKS
for i in ${!PROJECTS[@]}
do
    #EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value.\"${PROJECTS[$i]}\"")
    EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value | to_entries[] | (.value)")
    #REGIONS=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_regions\")) | .value.value.\"${PROJECTS[$i]}\"")
    REGIONS=$(echo $output |jq -r ".| to_entries[] | select(.key|endswith(\"_regions\")) | .value.value | to_entries[] | (.value)")
    for cluster in ${EKS_CLUSTER_NAMES}
    do
        if [[ ! ${cluster} == "null" ]]; then
            for region in $REGIONS
            do
                if [[ ! ${region} == "null" ]]; then
                    echo
                    echo "${PROJECTS[$i]} / ${region} - Authenticating to EKS Cluster ${cluster}"
                    # get identity
                    aws sts get-caller-identity
                    # add EKS cluster to $HOME/.kube/config
                    aws eks --region $region update-kubeconfig --name $cluster --alias "${cluster##*-}" 
                fi
            done
        fi
    done
done

# Setup EKS aliases per project
echo
echo "EKS Environments"
echo
for i in ${!PROJECTS[@]}
do
    #EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value.\"${PROJECTS[$i]}\"")
    EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value | to_entries[] | (.value)")
    #REGIONS=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_regions\")) | .value.value.\"${PROJECTS[$i]}\"")
    REGIONS=$(echo $output |jq -r ".| to_entries[] | select(.key|endswith(\"_regions\")) | .value.value | to_entries[] | (.value)")
    for cluster in ${EKS_CLUSTER_NAMES}
    do
        if [[ ! ${cluster} == "null" ]]; then
            for region in $REGIONS
            do
                if [[ ! ${region} == "null" ]]; then
                    echo "${PROJECTS[$i]}"
                    echo "  Region: ${region}"
                    echo "  EKS_CLUSTER_NAMES: ${cluster}"
                    #alias $(echo ${PROJECTS[$i]})="kubectl config use-context ${PROJECTS[$i]}"
                    alias $(echo ${region:3:4})="kubectl config use-context ${PROJECTS[$i]}"
                    alias $(echo ${cluster##*-})="kubectl config use-context ${cluster##*-}"
                    #echo "  alias: ${PROJECTS[$i]} = kubectl config use-context ${PROJECTS[$i]}"
                    echo "  alias: ${region:3:4} = kubectl config use-context ${PROJECTS[$i]}"
                    echo "  alias: ${cluster##*-} =  kubectl config use-context ${cluster##*-}"
                    echo
                fi
            done
        fi
    done
done
echo "extra aliases"
echo "  alias: kk=kubectl -n kube-system"
echo "  alias: kc=kubectl -n consul"
echo "  alias: kw=kubectl -n web"
echo "  alias: ka=kubectl -n api"

# Setup Global aliases
alias 'kc=kubectl -n consul'
alias 'kw=kubectl -n web'
alias 'ka=kubectl -n api'
alias 'kk=kubectl -n kube-system'
