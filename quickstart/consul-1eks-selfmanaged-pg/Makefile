.PHONY: all init deploy plan destroy fmt clean
.PHONY: consul-install consul-use1 consul-usw2 awslb dataplane fake-service

K8S_CONTEXT=`terraform output -json usw2_projects | jq -r '.[]'`

all: infra-install eks-connect consul-install metrics-install metrics-install-istio run-fortio-tests destroy
destroy: eks-connect metrics-clean consul-clean infra-clean
demo: infra-install eks-connect consul-install metrics-install run-fortio-tests-demo

fmt:
	@terraform fmt -recursive

init: fmt
	@terraform init

infra-install: init
	@-terraform apply -auto-approve
	@sleep 5
	@terraform apply -auto-approve

eks-connect:
	@source "../../scripts/kubectl_connect_eks.sh" .
	@kubectl cluster-info
	@kubectl config use-context ${K8S_CONTEXT}

consul-install:
	@terraform -chdir="consul_helm_values" init
	@terraform -chdir="consul_helm_values" apply -auto-approve
	@echo "Login to Consul UI - https://"
	@kubectl -n consul get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].hostname'
	@echo "Token"
	@kubectl -n consul get secrets consul-bootstrap-acl-token --template "{{ .data.token | base64decode }}"
	@echo

consul-install-noacltls-metrics-notproxy:
	@kubectl create namespace consul
	@secret=$(cat ../../files/consul.lic)
	@kubectl -n consul create secret generic consul-ent-license --from-literal="key=${secret}"
	@helm install consul-usw2-app1 hashicorp/consul --namespace consul --version 1.1.1 --values ./consul_helm_values/yaml/consul-values-noACL-noTLS.yaml
	@../../metrics/deploy_helm.sh -c "consul-server:8500"
	@../../metrics/fortio-tests-noACLs/deploy.sh

metrics-install:
	@../../metrics/deploy_helm.sh -c "consul-server:8500"
	@../../metrics/fortio-baseline-tests/deploy.sh
	@../../metrics/fortio-consul-tests/deploy.sh

metrics-install-istio:
	@../../scripts/install_istio.sh .
	@../../metrics/fortio-istio-tests/deploy.sh

run-fortio-tests:
	@../../metrics/scripts/seq_fortio_cli_runs.sh -k ${K8S_CONTEXT} -t "tcp" -c "16"  -d300 -w5 -p 1024 -f ./tmp
	@../../metrics/scripts/seq_fortio_cli_runs.sh -k ${K8S_CONTEXT} -t "http" -c "16"  -d300 -w5 -p 1024 -f ./tmp
	@../../metrics/scripts/seq_fortio_cli_runs.sh -k ${K8S_CONTEXT} -t "grpc" -c "16"  -d300 -w5 -p 1024 -f ./tmp

metrics-clean:
	@-../../metrics/deploy_helm.sh -d
	@-../../metrics/fortio-baseline-tests/deploy.sh -d
	@-../../metrics/fortio-consul-tests/deploy.sh -d
	@-../../metrics/fortio-istio-tests/deploy.sh -d
	@-../../metrics/fortio-tests-noACLs/deploy.sh -d
	@-istioctl x uninstall --purge -y

consul-clean: eks-connect metrics-clean
	@-terraform -chdir="consul_helm_values" destroy -auto-approve 
	@-kubectl -n consul delete secrets consul-ent-license
	@-kubectl delete ns consul

infra-clean:
	@terraform destroy -auto-approve 

clean:
	-rm -rf .terraform/
	-rm .terraform.lock.hcl
	-rm terraform.tfstate*