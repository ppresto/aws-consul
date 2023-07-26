.PHONY: all init infra plan destroy fmt clean
.PHONY: consul consul-info awslb dataplane fake-service

OUTPUT=`terraform output -raw`

all: infra consul

init: fmt
	@doormat login && eval $(doormat aws export -a aws_ppresto_test)
	@terraform init

infra: init
	@-terraform apply -auto-approve
	@sleep 5
	@terraform apply -auto-approve
	@source "../../scripts/kubectl_connect_eks.sh" .
	@../../scripts/install_awslb_controller.sh .

consul: dataplane consul-info fake-service

awslb:
	@../../scripts/install_awslb_controller.sh .

dataplane:
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -auto-approve

consul-info:
	@echo "Login to Consul UI- East"
	@source "../../scripts/setHCP-ConsulEnv-use1.sh" .
	@echo
	@echo "Login to Consul UI - West"
	@source "../../scripts/setHCP-ConsulEnv-usw2.sh" .
	@echo

fake-service:
	@ "../../examples/apps-peer-dataplane-eks-ap-def/fake-service/deploy-with-failover.sh"

consul-clean:
	@-../../examples/apps-peer-dataplane-eks-ap-def/fake-service/deploy-with-failover.sh del
	@-terraform -chdir="consul_helm_values" destroy -auto-approve

plan: init
	@terraform validate
	@terraform plan

destroy: init consul-clean
	@../../scripts/install_awslb_controller.sh . delete
	@terraform destroy -auto-approve

fmt:
	@terraform fmt -recursive

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*