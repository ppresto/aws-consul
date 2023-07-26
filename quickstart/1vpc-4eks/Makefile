.PHONY: all init destroy fmt clean
.PHONY: infra eks-connect consul-server consul-dataplane awslb

K8S_CONTEXT=`terraform output -json usw2_projects | jq -r '.[]'`

all: infra consul patch-coredns-consul-sd
destroy: consul-clean infra-clean

fmt:
	@terraform fmt -recursive

init: fmt
	@terraform init

infra: init
	@-terraform apply -auto-approve

eks-connect:
	@source "../../scripts/kubectl_connect_eks.sh" .

awslb:
	@../../scripts/install_awslb_controller.sh .

consul: consul-server consul-info

consul-server: eks-connect awslb
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -target=module.consul_presto-usw2-consul1 -target=module.consul_presto-usw2-consul2 -auto-approve

consul-dataplane:
	@../../scripts/update-SelfHosted-dataplane-yaml.sh -f ./consul_helm_values/auto-presto-usw2-eks1.tf -k consul1
	@terraform -chdir="consul_helm_values" apply -target=module.consul_presto-usw2-eks1 -auto-approve
	@../../scripts/update-SelfHosted-dataplane-yaml.sh -f ./consul_helm_values/auto-presto-usw2-eks2.tf -k consul2
	@terraform -chdir="consul_helm_values" apply -target=module.consul_presto-usw2-eks2 -auto-approve

consul-patch-coredns:
	@kubectl config use-context consul1
	@../../scripts/patch_coredns_to_fwd_to_consul.sh
	@kubectl config use-context consul2
	@../../scripts/patch_coredns_to_fwd_to_consul.sh

consul-info:
	@kubectl config use-context consul1
	@../../scripts/setConsulEnv.sh
	@kubectl config use-context consul2
	@../../scripts/setConsulEnv.sh

consul-clean: eks-connect
	@-terraform -chdir="consul_helm_values" destroy -auto-approve

awslb-clean:
	@-../../scripts/install_awslb_controller.sh . delete

infra-clean: awslb-clean
	@terraform destroy -auto-approve

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*