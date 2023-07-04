# terraform-aws-azure-load-test

## Deploy the monitoring stack with Helm
Current Monitoring Stack:
* prometheus
* prometheus-consul-exporter
* grafana

```
./metrics/deploy_helm.sh
```

## Consul Telemetry endpoints

Verify Consul Server monitoring endpoints
```
# consul server
kc -n consul exec -it deploy/consulcli -- curl http://127.0.0.1:8500/v1/agent/metrics\?format\=prometheus

# prometheus consul exporter
kubectl -n consul exec -it deploy/consulcli -- curl http://prometheus-consul-exporter:9107/metric
```

### Prometheus API
Set Prometheus start/end time for queries.  
* 2023-05-17T00:35:57Z
* 2023-05-17T00:40:57Z
  
**FYI: Using busybox date command that lives in consul container**
```
start=$(date +'%Y-%m-%dT%H:%M:%SZ' -d@"$(( `date +%s`-300))")
end=$(date +'%Y-%m-%dT%H:%M:%SZ')
```
Start time is 5 min in the past.

Using kubectl to exec command in consul container
```
kubectl -n consul exec -it consul-server-0 -- sh -c "export starttime=\$(date +'%Y-%m-%dT%H:%M:%SZ' -d@\"\$(( `date +%s`-300))\") &&
export endtime=\$(date +'%Y-%m-%dT%H:%M:%SZ') &&
printenv | grep time"

kubectl -n consul exec -it deploy/consulcli -- sh -c "export starttime=\$(date +'%Y-%m-%dT%H:%M:%SZ' -d@\"\$(( `date +%s`-300))\") &&
export endtime=\$(date +'%Y-%m-%dT%H:%M:%SZ') &&
printenv | grep time"
```


Prometheus `query` on cli (mem usage)
```
start=$(date +'%Y-%m-%dT%H:%M:%SZ' -d@"$(( `date +%s`-300))")
curl -s prometheus-server.metrics/api/v1/query \
--header 'Content-Type: application/x-www-form-urlencoded'  \
--data-urlencode 'query=container_cpu_usage_seconds_total{namespace="fortio-consul-100", pod="fortio-client-58484897bd-nw84g",container="consul-dataplane"}' \
--data-urlencode start=$start | jq -r '.data.result[].value[]'
```

Prometheus `query_range` on cli (cpu usage)
```
start=$(date +'%Y-%m-%dT%H:%M:%SZ' -d@"$(( `date +%s`-300))")
end=$(date +'%Y-%m-%dT%H:%M:%SZ')
curl -s prometheus-server.metrics/api/v1/query_range \
--header 'Content-Type: application/x-www-form-urlencoded'  \
--data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{namespace="fortio-consul-100", pod="fortio-client-58484897bd-nw84g",container="consul-dataplane"}[5m]))' \
--data-urlencode start=$start \
--data-urlencode end=$end  \
--data-urlencode step=1m | jq -r '.data.result[].values[]'
```

Prometheus query_range with kubectl (cpu usage)
```
kubectl -n consul exec -it deploy/consulcli -- sh -c "export starttime=\$(date +'%Y-%m-%dT%H:%M:%SZ' -d@\"\$(( `date +%s`-300))\") &&
export endtime=\$(date +'%Y-%m-%dT%H:%M:%SZ') &&
curl -s prometheus-server.metrics/api/v1/query_range \
--header 'Content-Type: application/x-www-form-urlencoded'  \
--data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{namespace=\"fortio-consul-100\", pod=\"fortio-client-58484897bd-nw84g\",container=\"consul-dataplane\"}[5m]))' \
--data-urlencode start=\$starttime \
--data-urlencode end=\$endtime  \
--data-urlencode step=1m | jq -r '.data.result[].values[5][1]'"

kubectl -n consul exec -it deploy/consulcli -- sh -c "export starttime=\$(date +'%Y-%m-%dT%H:%M:%SZ' -d@\"\$(( `date +%s`-300))\") &&
export endtime=\$(date +'%Y-%m-%dT%H:%M:%SZ') &&
curl -s prometheus-server.metrics/api/v1/query_range \
--header 'Content-Type: application/x-www-form-urlencoded'  \
--data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{namespace=\"fortio-consul-default\", pod=~\"fortio-client.*\",container=\"consul-dataplane\"}[5m]))' \
--data-urlencode start=\$starttime \
--data-urlencode end=\$endtime  \
--data-urlencode step=1m | jq -r '.data.result[].values[5][1]'"
```

Prometheus query with kubectl (mem usage)
```
kubectl -n consul exec -it consul-server-0 -- sh -c "export starttime=\$(date +'%Y-%m-%dT%H:%M:%SZ' -d@\"\$(( `date +%s`-300))\") &&
export endtime=\$(date +'%Y-%m-%dT%H:%M:%SZ') &&
curl -s prometheus-server.metrics/api/v1/query \
--header 'Content-Type: application/x-www-form-urlencoded'  \
--data-urlencode 'query=sum(container_memory_working_set_bytes{namespace=\"fortio-consul-100\", pod=\"fortio-client-58484897bd-nw84g\",container=\"consul-dataplane\"})' \
--data-urlencode start=\$starttime | jq -r '.data.result[].value[1]'"

kubectl -n consul exec -it deploy/consulcli -- sh -c "export starttime=\$(date +'%Y-%m-%dT%H:%M:%SZ' -d@\"\$(( `date +%s`-300))\") &&
export endtime=\$(date +'%Y-%m-%dT%H:%M:%SZ') &&
curl -s prometheus-server.metrics/api/v1/query \
--header 'Content-Type: application/x-www-form-urlencoded'  \
--data-urlencode 'query=sum(container_memory_working_set_bytes{namespace=\"fortio-consul-default\", pod=~\"fortio-client.*\",container=\"consul-dataplane\"})' \
--data-urlencode start=\$starttime | jq -r '.data.result[].value[1]'"
```