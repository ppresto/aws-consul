.PHONY: all init destroy fmt clean
.PHONY: infra eks-connect awslb doctorconsul

all: infra eks-connect doctorconsul
destroy: doctorconsul-clean infra-clean

fmt:
	@terraform fmt -recursive

init: fmt
	@terraform init

infra: init
	@terraform apply -auto-approve

eks-connect:
	@source "../../scripts/kubectl_connect_eks.sh" .

awslb:
	@../../scripts/install_awslb_controller.sh .

doctorconsul:
	@../../scripts/run_doctorconsul.sh

doctorconsul-clean:
	@../../scripts/run_doctorconsul.sh -delete

awslb-clean:
	@-../../scripts/install_awslb_controller.sh . delete

infra-clean:
	@terraform destroy -auto-approve