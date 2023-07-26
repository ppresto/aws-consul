#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

#   Populate the dataplane helm values files in ./consul_helm_values with the required information from the self hosted servers.
#   - External Server Endpoint
#   - ACL Token
#   - CA File
#
#   Terraform module `helm_install_consul` will use this to boostrap the dataplane to the correct consul cluster.

updateHelmInstall(){
    sed -i -e "s/NO_HCP_SERVERS/$(kubectl -n consul --context=${CTX} get svc consul-expose-servers -o json | jq -r '.status.loadBalancer.ingress[].hostname')/" ${FILE_PATH}
    sed -i -e "s/hcp_consul_root_token_secret_id.*/hcp_consul_root_token_secret_id = \"$(kubectl --context=${CTX} -n consul get secret consul-bootstrap-acl-token --template "{{.data.token | base64decode}}")\"/g" ${FILE_PATH}
    sed -i -e "s/hcp_consul_ca_file.*/hcp_consul_ca_file = \"$(kubectl --context=${CTX} -n consul get secret consul-ca-cert -o json | jq -r '.data."tls.crt"')\"/g" ${FILE_PATH}
    rm "${FILE_PATH}-e"
}

usage() { 
    echo "Usage: $0 [-f <file_path_to_helm_module.tf>] [-k <k8s context>]" 1>&2; 
    echo
    echo "Example: $0 -f ./consul_helm_values/auto-presto-usw2-eks1.tf] -k consul1"
    exit 1; 
}

while getopts "k:f:" o; do
    case "${o}" in
        f)  FILE_PATH="${OPTARG}"
            if [[ ! -f $FILE_PATH ]]; then
                echo "Error: $FILE_PATH does not exist"
                usage
            fi
            echo "Setting File to ${FILE_PATH}"
            ;;
        k)  CTX="${OPTARG}"
            echo "Setting K8S_CONTEXT  to ${CTX}"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

updateHelmInstall
