.PHONY: all init deploy destroy fmt clean
.PHONY: consul-install awslb fake-service

K8S_CONTEXT=`terraform output -json usw2_projects | jq -r '.[]'`

all: infra-deploy eks-connect awslb consul-install
destroy: consul-clean infra-clean

fmt:
	@terraform fmt -recursive

init: fmt
	@terraform init

infra-deploy: init
	@-terraform apply -auto-approve
	@sleep 5
	@terraform apply -auto-approve

eks-connect:
	@source "../../scripts/kubectl_connect_eks.sh" .
	@kubectl cluster-info
	@kubectl config use-context ${K8S_CONTEXT}

awslb:
	@../../scripts/install_awslb_controller_by_project.sh .

consul-install:
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -auto-approve
	@echo "Login to Consul UI - https://"
	@kubectl -n consul get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname'
	@echo "Token"
	@kubectl -n consul get secrets consul-bootstrap-acl-token --template "{{ .data.token | base64decode }}"

consul-clean: eks-connect metrics-clean
	@-terraform -chdir="consul_helm_values" destroy -auto-approve

infra-clean:
	@terraform destroy -auto-approve