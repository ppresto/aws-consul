.PHONY: all init deploy destroy fmt clean
.PHONY: consul-install awslb fake-service

K8S_CONTEXT=`terraform output -json usw2_projects | jq -r '.[0]'`
CONSUL_UI=`terraform output -raw usw2_consul_private_endpoint_url`

all: infra-deploy eks-connect awslb consul-install metrics-install run-fortio-tests
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
	@../../scripts/install_awslb_controller.sh .

consul-install:
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -auto-approve

consul-clean: eks-connect metrics-clean
	@-terraform -chdir="consul_helm_values" destroy -auto-approve

infra-clean:
	@terraform destroy -auto-approve

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*