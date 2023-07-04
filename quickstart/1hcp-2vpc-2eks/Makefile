.PHONY: all init deploy plan destroy fmt clean
.PHONY: consul consul-info consul-use1 consul-usw2 awslb dataplane fake-service

all: deploy consul

fmt:
	@terraform fmt -recursive
	
init: fmt
	@terraform init

deploy: init
	@terraform apply -auto-approve
	@echo "Source the following script to connect to all EKS clusters"
	@echo
	@echo "source ../../scripts/kubectl_connect_eks.sh ."

consul: awslb dataplane consul-info fake-service

awslb:
	@../../scripts/install_awslb_controller.sh .

dataplane:
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -auto-approve

consul-info:
	@echo "Login to Consul UI - West"
	@source "../../scripts/setHCP-ConsulEnv-usw2.sh" .
	@echo

fake-service:
	@ "../../examples/apps-2vpc-dataplane-ap-def/fake-service/deploy.sh"

consul-clean:
	@ ../../examples/apps-2vpc-dataplane-ap-def/fake-service/deploy.sh delete
	@-terraform -chdir="consul_helm_values" destroy -auto-approve
	@- helm uninstall -n kube-system aws-load-balancer-controller eks/aws-load-balancer-controller
	@terraform destroy -auto-approve

destroy: init consul-clean
	@terraform destroy -auto-approve 

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*