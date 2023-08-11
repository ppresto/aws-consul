#!/bin/bash

# This script requires an aws profile be used for AutnN.
# Im using 'assumed-role' profile when authenticating with Doormat.
# This script will add the EKS cluster to this profile.  If using K8s IDE like Lens this profile is needed
# to authN to K8s because the IDE doesn't have access to the local shell variables.
#
# Example Doormat Login Command
#
# doormat login \
# && eval $(doormat aws export -a aws_ppresto_test) \
# && aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID --profile assumed-role \
# && aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY --profile assumed-role \
# && aws configure set aws_session_token $AWS_SESSION_TOKEN --profile assumed-role \
# && aws configure set region us-west-2 --profile assumed-role

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
PROFILE="assumed-role"

# Setup local AWS Env variables
if [[ -z $1 ]]; then  #Pass path for tfstate dir if not in quickstart.
output=$(terraform output -state $SCRIPT_DIR/../quickstart/terraform.tfstate -json)
else
output=$(terraform output -state ${1}/terraform.tfstate -json)
fi

EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names_to_region\")) | .value.value | to_entries[] | (.key)")
for cluster in ${EKS_CLUSTER_NAMES}
do
    if [[ ! ${cluster} == "null" ]]; then
        region=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names_to_region\")) | .value.value.\"${cluster}\"")
        echo
        echo "${cluster} / ${region}"
        # get identity
        aws sts get-caller-identity
        # add EKS cluster to $HOME/.kube/config
        echo "aws eks --region $region update-kubeconfig --name $cluster --alias "${cluster##*-}" --profile ${PROFILE}"
        aws eks --region $region update-kubeconfig --name $cluster --alias "${cluster##*-}" --profile "${PROFILE}" 
    fi
done

# Setup EKS aliases per project
echo
echo "EKS Environments"
echo

EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names_to_region\")) | .value.value | to_entries[] | (.key)")
for cluster in ${EKS_CLUSTER_NAMES}
do
    if [[ ! ${cluster} == "null" ]]; then
        region=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names_to_region\")) | .value.value.\"${cluster}\"")
        echo "  EKS_CLUSTER_NAME: ${cluster}"
        echo "  Region: ${region}"
        alias $(echo ${cluster##*-})="kubectl config use-context ${cluster##*-}"
        echo "  alias: ${cluster##*-} =  kubectl config use-context ${cluster##*-}"
        echo
    fi
done

# Setup Global aliases
alias 'kc=kubectl -n consul'
alias 'kw=kubectl -n web'
alias 'ka=kubectl -n api'
alias 'kk=kubectl -n kube-system'

echo "extra aliases"
echo "  alias: kk=kubectl -n kube-system"
echo "  alias: kc=kubectl -n consul"
echo "  alias: kw=kubectl -n web"
echo "  alias: ka=kubectl -n api"