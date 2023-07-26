.PHONY: all init destroy fmt clean
.PHONY: infra eks-connect consul-server consul-dataplane awslb

K8S_CONTEXT=`terraform output -json usw2_projects | jq -r '.[]'`

all: infra eks-connect awslb consul
destroy: consul-clean infra-clean

fmt:
	@terraform fmt -recursive

init: fmt
	@terraform init

infra: init
	@-terraform apply -auto-approve
	@sleep 5
	@terraform apply -auto-approve

eks-connect:
	@source "../../scripts/kubectl_connect_eks.sh" .

awslb:
	@../../scripts/install_awslb_controller.sh .

awslb-clean:
	@-../../scripts/install_awslb_controller.sh . delete

consul: consul-server consul-dataplane consul-info

consul-server: eks-connect awslb
	@terraform apply -auto-approve
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -target=module.consul_presto-usw2-consul1 -target=module.consul_presto-usw2-consul2 -auto-approve

consul-dataplane:
	@../../scripts/update-SelfHosted-dataplane-yaml.sh -f ./consul_helm_values/auto-presto-usw2-app1.tf -k consul1
	@../../scripts/update-SelfHosted-dataplane-yaml.sh -f ./consul_helm_values/auto-presto-usw2-app2.tf -k consul2
	@terraform -chdir="consul_helm_values" apply -target=module.consul_presto-usw2-app1 -auto-approve
	@terraform -chdir="consul_helm_values" apply -target=module.consul_presto-usw2-app2 -auto-approve

consul-info:
	@echo "Login to Consul1 UI - https://"
	@kubectl -n consul --context=consul1 get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname'
	@echo "Token"
	@kubectl -n consul --context=consul1 get secrets consul-bootstrap-acl-token --template "{{ .data.token | base64decode }}"
	@echo
	@echo "Login to Consul2 UI - https://"
	@kubectl -n consul --context=consul2 get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname'
	@echo "Token"
	@kubectl -n consul --context=consul2 get secrets consul-bootstrap-acl-token --template "{{ .data.token | base64decode }}"

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