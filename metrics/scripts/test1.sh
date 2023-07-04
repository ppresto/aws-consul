baseline_grpc() {
    if [[ -z $NAMESPACE ]]; then
        NAMESPACE="fortio-baseline"
        Label="Baseline-GRPC"
    else
        Label="GRPC-${NAMESPACE}"
    fi
    for c in "${CONNECTIONS[@]}"
    do
        DATE=$(date '+%m%d%Y-%H%M%S')
        REPORT="${FILE_PATH}/$(echo ${Label}|sed s"/ /_/g")_${NAMESPACE}_${c}c_${DATE}.json"
        echo "Running ${Label} for ${DURATION}s with $c connections in K8s ns $NAMESPACE"
        kubectl -n $NAMESPACE --context ${K8S_CONTEXT} exec -i deploy/fortio-client -c fortio -- fortio load -grpc -ping -qps ${QPS} -c $c -s 1 -r .0001 -t ${DURATION}s ${HEADERS} -payload "${PAYLOADBYTES}" -a -labels "${Label}" ${JSON} fortio-server-defaults:8079 > "${REPORT}"
        sleep $RECOVERY_TIME
        report $REPORT $DATE ${NAMESPACE}
    done
    echo
    echo "To See Load Test results port-forward fortio client and click on Browse 'saved results'"
    echo "kubectl -n $NAMESPACE port-forward deploy/fortio-client 8080:8080"
    echo
    echo "http://localhost:8080/fortio"
}