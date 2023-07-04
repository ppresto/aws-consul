#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

#   Populate the dataplane helm values files in ./consul_helm_values with the required information from the self hosted servers.
#   - External Server Endpoint
#   - ACL Token
#   - CA File
#
#   Terraform module `helm_install_consul` will use this to boostrap the dataplane to the correct consul cluster.


# Setup local AWS Env variables
if [[ -z $1 ]]; then  #Pass path for tfstate dir if not in quickstart.
FILE_PATH="./consul_helm_values"
else
FILE_PATH="${1}/consul_helm_values"
fi

if [[ ! -d ${FILE_PATH} ]]; then
    echo "BAD FILE_PATH: $FILE_PATH"
    exit 1
fi

#
# DC 1
#
FILE="auto-presto-usw2-app1.tf"
CTX="consul1"
sed -i -e "s/NO_HCP_SERVERS/$(kubectl -n consul --context=${CTX} get svc consul-expose-servers -o json | jq -r '.status.loadBalancer.ingress[].hostname')/" ${FILE_PATH}/${FILE}
sed -i -e "s/hcp_consul_root_token_secret_id.*/hcp_consul_root_token_secret_id = \"$(kubectl --context=${CTX} -n consul get secret consul-bootstrap-acl-token --template "{{.data.token | base64decode}}")\"/g" ${FILE_PATH}/${FILE}
sed -i -e "s/hcp_consul_ca_file.*/hcp_consul_ca_file = \"$(kubectl --context=${CTX} -n consul get secret consul-ca-cert -o json | jq -r '.data."tls.crt"')\"/g" ${FILE_PATH}/${FILE}

#
# DC 2
#
FILE="auto-presto-usw2-app2.tf"
CTX="consul2"
sed -i -e "s/NO_HCP_SERVERS/$(kubectl -n consul --context=${CTX} get svc consul-expose-servers -o json | jq -r '.status.loadBalancer.ingress[].hostname')/" ${FILE_PATH}/${FILE}
sed -i -e "s/hcp_consul_root_token_secret_id.*/hcp_consul_root_token_secret_id = \"$(kubectl --context=${CTX} -n consul get secret consul-bootstrap-acl-token --template "{{.data.token | base64decode}}")\"/g" ${FILE_PATH}/${FILE}
sed -i -e "s/hcp_consul_ca_file.*/hcp_consul_ca_file = \"$(kubectl --context=${CTX} -n consul get secret consul-ca-cert -o json | jq -r '.data."tls.crt"')\"/g" ${FILE_PATH}/${FILE}
