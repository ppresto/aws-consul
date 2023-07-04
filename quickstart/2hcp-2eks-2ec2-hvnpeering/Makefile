.PHONY: all init deploy plan destroy fmt clean
.PHONY: consul consul-info consul-use1 consul-usw2 awslb dataplane fake-service

OUTPUT=`terraform output -raw`

all: deploy consul

init: fmt
	@doormat login && eval $(doormat aws export -a aws_ppresto_test)
	@terraform init

deploy: init
	@-terraform apply -auto-approve
	@sleep 30
	@terraform apply -auto-approve
	@source "../../scripts/kubectl_connect_eks.sh" .
	@kubectl config use-context usw2-app1
	@kubectl cluster-info

consul: awslb dataplane consul-info fake-service

awslb:
	@../../scripts/install_awslb_controller.sh .

dataplane:
	@terraform -chdir="consul_helm_values" apply -auto-approve

consul-info:
	@echo "Login to Consul UI- East"
	@source "../../scripts/setHCP-ConsulEnv-use1.sh" .
	@echo
	@echo "Login to Consul UI - West"
	@source "../../scripts/setHCP-ConsulEnv-usw2.sh" .
	@echo
# This may not require peering script anymore.  Should be completed in TF.
fake-service:
	@ "../../examples/apps-peer-dataplane-ap-def/peering/peer_east_to_west.sh"
	@ "../../examples/apps-peer-dataplane-ap-def/fake-service/deploy-with-failover.sh"
consul-use1:
	@source "../../scripts/setHCP-ConsulEnv-use1.sh" .

consul-usw2:
	@source "../../scripts/setHCP-ConsulEnv-usw2.sh" .

consul-clean:
	@-../../examples/apps-peer-dataplane-ap-def/peering/peer_east_to_west.sh del
	@-../../examples/apps-peer-dataplane-ap-def/fake-service/deploy-with-failover.sh del
	@-terraform -chdir="consul_helm_values" destroy -auto-approve 
	@- helm uninstall -n kube-system aws-load-balancer-controller eks/aws-load-balancer-controller

plan: init
	@terraform validate
	@terraform plan

destroy: init consul-clean
	@terraform destroy -auto-approve 

fmt:
	@terraform fmt -recursive

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*