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

awslb-clean:
	@-../../scripts/install_awslb_controller.sh . delete

consul: consul-server consul-info consul-patch-coredns

consul-server: eks-connect awslb
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -auto-approve

consul-patch-coredns:
	@kubectl config use-context consul1
	@../../scripts/patch_coredns_to_fwd_to_consul.sh
	@kubectl config use-context consul2
	@../../scripts/patch_coredns_to_fwd_to_consul.sh

consul-peer-dc1-to-dc2:
	@../../esm/peering/peer_dc1_to_dc2.sh

consul-esm-deploy-learn:
	@../../esm/k8s-with-agent/deploy.sh

consul-info:
	@kubectl config use-context consul1
	@setConsulEnv.sh
	@kubectl config use-context consul2
	@setConsulEnv.sh

consul-clean: eks-connect
	@-terraform -chdir="consul_helm_values" destroy -auto-approve
	@-kubectl -n consul --context=consul1 delete secrets consul-ca-cert consul-bootstrap-acl-token
	@-kubectl -n consul --context=consul2 delete secrets consul-ca-cert consul-bootstrap-acl-token

infra-clean: awslb-clean
	@terraform destroy -auto-approve

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*