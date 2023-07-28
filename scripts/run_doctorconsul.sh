#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
TF_STATE_FILE=$(echo "${SCRIPT_DIR}/../quickstart/1vpc-eksonly/terraform.tfstate" | sed "s|\/|\\\\\/|g")
DRCONSUL_DIR="${SCRIPT_DIR}/../../doctorconsul"

install() {
    echo "DoctorConsul Dir:  $DRCONSUL_DIR"
    if [[ ! -d ${DRCONSUL_DIR} ]]; then 
        echo "Dir not found. Cloning repo..."
        git clone https://github.com/joshwolfer/doctorconsul.git ${DRCONSUL_DIR}
    fi

    if [[ -f ${SCRIPT_DIR}/../files/consul.lic ]]; then
        echo "cp ${SCRIPT_DIR}/../files/consul.lic ${DRCONSUL_DIR}/license"
        cp ${SCRIPT_DIR}/../files/consul.lic ${DRCONSUL_DIR}/license
    else
        echo "REQUIRED: Copy Consul license to: ${DRCONSUL_DIR}/license"
        exit 1
    fi

    # mac sed inline replace fix (add .bkup ext and cleanup)
    find ${DRCONSUL_DIR}/kube/configs/dc3/services -type f -exec sed -i .bkup 's|image: k3d-doctorconsul\.localhost:12345/nicholasjackson/fake-service:v|image: nicholasjackson/fake-service:v|g' {} \;
    find ${DRCONSUL_DIR}/kube/configs/dc4/services -type f -exec sed -i .bkup 's|image: k3d-doctorconsul\.localhost:12345/nicholasjackson/fake-service:v|image: nicholasjackson/fake-service:v|g' {} \;
    find ${DRCONSUL_DIR}/kube/configs/ -type f -name "*.bkup" -exec rm {} \;

    echo "Updating EKSONLY_TF_STATE_FILE Path:  \"${TF_STATE_FILE}\""
	sed -i bkup -e "s/EKSONLY_TF_STATE_FILE=.*/EKSONLY_TF_STATE_FILE=\"${TF_STATE_FILE}\"/" ${DRCONSUL_DIR}/kube-config.sh
    cd ${DRCONSUL_DIR}
	./kube-config.sh -eksonly
	cd -
}
delete () {
    cd ${DRCONSUL_DIR}
	./kill.sh -eksonly
	cd -
}

#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting DoctorConsul"
    delete
else
    echo "Deploying DoctorConsul"
    install
fi