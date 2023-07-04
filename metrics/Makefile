.PHONY: all init deploy plan destroy fmt clean
.PHONY: consul-install consul-use1 consul-usw2 awslb dataplane fake-service

clean: metrics-clean
	@-rm -rf /tmp/*.json
	@-rm /tmp/fortio.results.csv

install:
	@./deploy/deploy_helm.sh
	@./deploy/fortio-tests/deploy.sh


metrics-install:
	@./deploy/deploy_helm.sh

fortio-install:
	@./deploy/fortio-tests/deploy.sh

fortio-run-http:
	@-./deploy/reports/parallel_http_tests.sh

fortio-run-grpc:
	@-./deploy/reports/parallel_grpc_tests.sh
	
metrics-clean: fortio-clean
	@-./deploy/deploy_helm.sh destroy

fortio-clean:
	@-./deploy/fortio-tests/deploy.sh destroy