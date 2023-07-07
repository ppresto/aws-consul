#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Setup local AWS Env variables
if [[ -z $1 ]]; then  #Pass path for tfstate dir if not in quickstart.
output=$(terraform output -state $SCRIPT_DIR/../quickstart/terraform.tfstate -json)
else
output=$(terraform output -state ${1}/terraform.tfstate -json)
fi
PROJECTS=($(echo $output | jq -r '. | to_entries[] | select(.key|endswith("_projects")) | .value.value[]'))

install() {
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
                        echo "${PROJECTS[$i]} / ${region} - Installing AWS LB Controller to EKS Cluster ${cluster}"
                        # get identity
                        aws sts get-caller-identity
                        # add EKS cluster to $HOME/.kube/config
                        aws eks --region $region update-kubeconfig --name $cluster

                        # IAM Role and Policy was already created by TF
                        # create aws lb controller service account and map to IAM role
cat >/tmp/aws-load-balancer-controller-service-account.yaml <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::729755634065:role/${cluster}-load-balancer-controller
EOF
                        kubectl apply -f /tmp/aws-load-balancer-controller-service-account.yaml
                        # Install Helm Chart
                        helm repo add eks https://aws.github.io/eks-charts
                        helm repo update
                        # helm search repo eks/aws-load-balancer-controller --versions
                        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                            -n kube-system \
                            --set clusterName="${cluster}" \
                            --set serviceAccount.create=false \
                            --set serviceAccount.name=aws-load-balancer-controller 

                        # Verify
                        sleep 5
                        kubectl get deployment -n kube-system aws-load-balancer-controller

                    fi
                done
            fi
        done
    done
}

delete () {
    # Authenticate to EKS
    for i in ${!PROJECTS[@]}
    do
            #EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value.\"${PROJECTS[$i]}\"")
            EKS_CLUSTER_NAMES=$(echo $output | jq -r ".| to_entries[] | select(.key|endswith(\"_eks_cluster_names\")) | .value.value | to_entries[] | (.value)")
            REGIONS=$(echo $output |jq -r ".| to_entries[] | select(.key|endswith(\"_regions\")) | .value.value | to_entries[] | (.value)")
        for cluster in ${EKS_CLUSTER_NAMES}
        do
            if [[ ! ${cluster} == "null" ]]; then
                for region in $REGIONS
                do
                    if [[ ! ${region} == "null" ]]; then
                        echo
                        echo "${PROJECTS[$i]} / ${region} - Deleting AWS LB Controller to EKS Cluster ${cluster}"
                        # get identity
                        aws sts get-caller-identity
                        kubectl config use-context ${PROJECTS[$i]}
                        helm uninstall -n kube-system --kube-context=${PROJECTS[$i]}  aws-load-balancer-controller
                    fi
                done
            fi
        done
    done
}
#Cleanup if any param is given on CLI
if [[ ! -z $2 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    install
fi