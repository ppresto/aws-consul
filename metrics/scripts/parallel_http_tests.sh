#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

NAMESPACES=($(kubectl get ns -o json | jq -r '.items[].metadata.name' | grep fortio | grep -v tcp))
TEST_TYPE=(http)

# Only used in the consul-l7 test case, but adding header in all cases for simplicity.
HEADER="MY_CUSTOM_REQ_HEADER:XXXXXXXXXXXXXX"

#Run Baseline Test Cases
baseline(){
    c=${1}  # Pass Connection count to run test with
    for type in "${TEST_TYPE[@]}"
    do
        if [[ ${type} =~ consul_http ]]; then
            echo "Running Test Type 'baseline_http' in namespace fortio-baseline with $c connections"
            nohup ${SCRIPT_DIR}/fortio_cli.sh  -j -t baseline_http -n fortio-baseline -k${K8S_CONTEXT} -q${QPS} -d${DURATION} -w${RECOVERY_TIME} -c ${c} -h ${HEADER} -p ${PAYLOAD} -f ${FILE_PATH} &
            pid=$!
            wait $pid
            echo "Test completed (PID: $pid)"
        else
            echo echo "Running Test Type 'baseline_grpc' in namespace fortio-baseline with $c connections"
            nohup ${SCRIPT_DIR}/fortio_cli.sh  -j -t baseline_grpc -n fortio-baseline -k${K8S_CONTEXT} -q${QPS} -d${DURATION} -w${RECOVERY_TIME} -c ${c} -h ${HEADER} -p ${PAYLOAD} -f ${FILE_PATH} &
            pid=$!
            wait $pid
        fi
        # echo "waiting ${DURATION}s before next test..."
        # sleep ${DURATION}
    done
}

run () {
    # Consul Test Cases
    for c in "${CONNECTIONS[@]}"
    do
        for type in "${TEST_TYPE[@]}"
        do
            for ns in "${!NAMESPACES[@]}"
            do
                echo "Running Test Type '${type}' in namespace ${NAMESPACES[$ns]} with $c connections"
                nohup ${SCRIPT_DIR}/fortio_cli.sh -j -t ${type} -n ${NAMESPACES[$ns]} -q${QPS} -k${K8S_CONTEXT} -d ${DURATION} -w${RECOVERY_TIME} -c ${c}  -h ${HEADER} -p ${PAYLOAD} -f ${FILE_PATH} &
                pids[${ns}]=$!
            done
            baseline ${c}
            for pid in ${pids[@]}; do
                wait $pid
                echo "Test completed (PID: $pid)"
            done
        done
    done
}

usage() { 
    echo "Usage: $0 [-c <#threads>] [-d <DURATION>] [-k <K8S_CONTEXT>] [-f <report_path>]" 1>&2; 
    echo
    echo "Example: $0 -t consul_http -d 300 -c 32"
    exit 1; 
}

while getopts "d:c:n:t:p:w:jh:q:f:k:" o; do
    case "${o}" in
        q)
            QPS="${OPTARG}"
            if ! [[ ${QPS} =~ ^[0-9]+$ ]]; then
                usage
            fi
            ;;
        c)
            CONNECTIONS=(${OPTARG})
            if ! [[ ${CONNECTIONS} =~ ^[0-9]+$ ]]; then
                usage
            fi
            echo "Setting Connections to ${CONNECTIONS}"
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
                mkdir -p ${FILEPATH}
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

if [[ -z $CONNECTIONS ]]; then
    CONNECTIONS=(2 4 8 16 32 64)
    echo "Setting Connections to ${CONNECTIONS[@]}"
fi

if [[ -z $QPS ]]; then
    QPS=1000
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