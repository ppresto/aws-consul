#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

#NAMESPACES=(fortio-consul-tcp fortio-consul-default fortio-consul-optimized fortio-consul-logs fortio-consul-l7)
#NAMESPACES=($(kubectl get ns -o json | jq -r '.items[].metadata.name' | grep fortio))
#TEST_TYPE=(http)
# Only used in the consul-l7 test case, but adding header in all cases for simplicity.
HEADER="MY_CUSTOM_REQ_HEADER:XXXXXXXXXXXXXX"

run () {
    # Consul Test Cases
    for c in "${CONNECTIONS[@]}"
    do
        for type in "${TEST_TYPE[@]}"
        do
            for ns in "${!NAMESPACES[@]}"
            do
                echo "Running Test Type '${type}' in namespace ${NAMESPACES[$ns]} with $c connections"
                ${SCRIPT_DIR}/fortio_cli.sh -j -t ${type} -n ${NAMESPACES[$ns]} -k${K8S_CONTEXT} -d ${DURATION} -w${RECOVERY_TIME} -c${c} -h ${HEADER} -p ${PAYLOAD} -f ${FILE_PATH}
                pid=$!
                wait $pid
            done
        done
    done
}

usage() { 
    echo
    echo "Usage: $0 [-t <TEST_TYPES>] [-c <#threads>] [-d <DURATION>] [-k <K8S_CONTEXT>] [-w <wait_time>] [-f <report_path>]" 1>&2; 
    echo
    echo "Examples: "
    echo "           $0 -t \"tcp\" -c16  -d300 -w1 -f ./tmp"
    echo "           $0 -t \"http\" -c16  -d300 -w1 -f ./tmp"
    echo "           $0 -t \"http grpc\" -c16  -d300 -w1 -f ./tmp"
    exit 1; 
}

while getopts "d:c:n:t:p:w:jh:q:f:k:" o; do
    case "${o}" in
        c)
            CONNECTIONS=(${OPTARG})
            if ! [[ ${CONNECTIONS} =~ ^[0-9]+$ ]]; then
                usage
            fi
            echo "Setting Connections to ${CONNECTIONS}"
            ;;
        t)
            TEST_TYPE=(${OPTARG})
            if ! [[ ${TEST_TYPE} =~ ^[a-z]+$ ]]; then
                usage
            elif [[ ${TEST_TYPE} == "tcp" ]]; then
                NAMESPACES=($(kubectl get ns -o json | jq -r '.items[].metadata.name' | grep fortio | grep -E '(tcp|baseline)'))
            else
                NAMESPACES=($(kubectl get ns -o json | jq -r '.items[].metadata.name' | grep fortio | grep -v tcp))
            fi
            echo 
            ;;
        k)
            K8S_CONTEXT="${OPTARG}"
            echo "Setting K8S_CONTEXT  to ${K8S_CONTEXT}"
            ;;
        d)
            DURATION="${OPTARG}"
            echo "Setting Run Duration to ${DURATION}"
            ;;
        w)
            RECOVERY_TIME="${OPTARG}"
            echo "Setting Recovery Time of $RECOVERY_TIME between tests"
            ;;
        f)
            FILE_PATH="${OPTARG}"
            if [[ -d $FILE_PATH ]]; then 
                echo "Setting Reporting FILE_PATH to $FILE_PATH"
            else
                mkdir -p ${FILE_PATH}
                echo "$FILE_PATH Not Found.  Creating FILE_PATH $FILEPATH"
            fi
            ;;
        p)
            PAYLOAD="${OPTARG}"
            if ! [[ ${PAYLOAD} =~ ^[0-9]+$ ]]; then
                usage
            fi
            echo "Setting Payload to: ${PAYLOAD} bytes"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [[ -z $FILE_PATH ]]; then
    FILE_PATH="/tmp"
    echo "Setting Reporting FILE_PATH to $FILE_PATH"
fi

if [[ -z $TEST_TYPE ]]; then
    usage
    exit 1
fi

if [[ -z $CONNECTIONS ]]; then
    CONNECTIONS=(2 4 8 16 32 64)
    echo "Setting Connections to ${CONNECTIONS[@]}"
fi

if [[ -z $PAYLOAD ]]; then
    PAYLOAD=128
fi

if [[ -z $DURATION ]]; then
    DURATION=300
    echo "Setting run duration to ${DURATION}"
else
    echo "DURATION: $DURATION"
fi

if [[ -z $RECOVERY_TIME ]]; then
    RECOVERY_TIME=30
    echo "Setting Recovery Time of $RECOVERY_TIME between tests"
fi

if [[ -z $K8S_CONTEXT ]]; then
    K8S_CONTEXT=$(kubectl config current-context)
    echo "Setting K8S_CONTEXT to $K8S_CONTEXT"
fi

run