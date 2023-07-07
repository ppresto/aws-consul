# AWS Consul - Deploy Metrics Stack Prometheus-Grafana-Fortio

## PreReq
* Provision EKS Cluster and connect
* Deploy Consul Server
* kubectl
* helm
## Deploy the monitoring stack with Helm
Current Monitoring Stack:
* prometheus
* prometheus-consul-exporter
* grafana

```
metrics/deploy_helm.sh
```

## Deploy Consul Fortio load tests
There are multiple test cases contained within the `fortio-consul-tests` directory.

Deploy fortio test cases
```
metrics/fortio-consul-tests/deploy.sh
```

Undeploy test cases by providing any value as a parameter (ex: delete)
```
metrics/fortio-consul-tests/deploy.sh delete
```

## Deploy Istio Fortio load tests
There are multiple test cases contained within the `fortio-istio-tests` directory.

Deploy fortio test cases
```
metrics/fortio-istio-tests/deploy.sh
```

Undeploy test cases by providing any value as a parameter (ex: delete)
```
metrics/fortio-istio-tests/deploy.sh delete
```

## Fortio Quickstart
Fortio test cases for Consul, Istio, or both should have been deployed and are now ready to be load tested.  The `fortio_cli.sh` wrapper script should make this very easy.  Every test case lives within its on K8s namespace.  

Get a list of all available fortio test cases by K8s namespace
```
kubectl get ns -o json | jq -r '.items[].metadata.name' | grep fortio
```
HTTP or GRPC tests can be run on any of the above namespaces with the exception of TCP.  The TCP test cases live in a namespace appended with `tcp` and these only work for TCP tests. 


Quick CLI reference.

* -n Kubernetes namespace with target Fortio test case
* -j enables json output to stdout which is needed by -f. Otherwise, use `kubectl port-forward deploy/fortio 8080` to view graphs.
* -f write output to file_path. Requires -j
* -k k8s-context to override current-context
* -d 10 duration of test
* -q 1000 Queries per second
* -c 2 connections array. If not provided connections=(2 4 8 16 32 64)
* -w 0 no recovery time b/w tests 
* -h "KEY:VALUE" Add a Header
* -p 512  Payload in bytes

### HTTP Examples
```
fortio_cli.sh -t http -n fortio-consul-optimized -d10 -c16
fortio_cli.sh -j -t http -n fortio-consul-optimized -k usw2-app1 -d10 -p1024 -c16 -f ./tmp
fortio_cli.sh -j -t http -n fortio-consul-optimized -q1000 -d120 -h "MY_CUSTOM_REQ_HEADER:XXXXXXXXXXXXXX" -f ./tmp -c "4 8 16"
fortio_cli.sh -j -t http -n fortio-consul-default -d30 -p1024 -f ./tmp
```

### GRPC  Examples
```
fortio_cli.sh -t grpc -n fortio-consul-optimized -k usw2-app1 -d300 -c "2 4 8"
fortio_cli.sh -j -t grpc -n fortio-consul-optimized -d300 -c2 -p512 -h "MY_CUSTOM_REQ_HEADER:XXXXXXXXXXXXXX" -f ./tmp
```

### TCP Examples
See all available TCP fortio test cases
```
kubectl get ns -o json | jq -r '.items[].metadata.name' | grep fortio | grep tcp
```

Run CLI
```
fortio_cli.sh -t tcp -n fortio-istio-tcp -d3 -q1 -c1 -p1024
fortio_cli.sh -t tcp -n fortio-consul-tcp -d60 -q1000 -c16 -p1024 -jf ./tmp
```
### Run a single HTTP/GRPC performance test and write results to a file

`fortio-consul-optimized` has configured the dataplane with more cpu and memory then `fortio-consul-default` to support more conncurrent connections.  Use either test case to run a quick HTTP performance test.
```
metrics/scripts/fortio_cli.sh -j -t http -n fortio-consul-optimized -k usw2-app1 -d 10 -w 0 -c2 -f /tmp

../../metrics/scripts/fortio_cli.sh -j -t http -n fortio-consul-optimized -k usw2-app1 -d300 -p1024 -c16 -f ./tmp
```

single GRPC test
```
metrics/scripts/fortio_cli.sh -j -t grpc -n fortio-consul-optimized -d 10 -w0 -c2 -f /tmp
```

### Run a single test and use fortio UI to view results
By removing the -j option the report will not be written to stdout and live within the fortio-client container.
```
metrics/scripts/fortio_cli.sh -t http -n fortio-consul-optimized -d 10 -w 0 -c2
```
Once the test completes open the fortio UI in your browser.  
```
kubectl -n fortio-consul-optimized port-forward deploy/fortio-client 8080:8080
```
Go to http://localhost:8080/fortio
Run additional tests from the UI or Click on "Browse `saved results` (or `raw JSON`)" to view this last report.


### Run an HTTP performance test using L7 Intentions
The `fortio-consul-logs` test case sets proxy-defaults to enable the envoy access log and capture additional custom headers like "MY_CUSTOM_REQ_HEADER".  The `fortio-consul-l7` test case uses a l7 intention to verify all requests have this custom header set.  Use the `fortio-consul-l7` to run a successful and failed test to verify the l7 intention is working as expected.
* Open tab 1 - tail the envoy access logs
* Open tab 2 - run the `fortio-consul-l7` test.

Tab 1: Run successful test with correct header
```
metrics/scripts/fortio_cli.sh -j -t http -n fortio-consul-l7 -d 10 -w 0 -c2 -h "MY_CUSTOM_REQ_HEADER:Value" -f /tmp
```

Tab 2: Tail envoy access log
```
kubectl -n fortio-consul-l7 logs deploy/fortio-server-defaults -c consul-dataplane -f
```
Look for the `MY_CUSTOM_REQ_HEADER`, and verify you see a successful response `"response_code":200`. Keep this log tailing...


Next, go back to Tab 1 and run a failed test using a bad header.
```
metrics/scripts/fortio_cli.sh -j -t http -n fortio-consul-l7 -d 10 -w 0 -c2 -h "MY_BAD_HEADER:Value" -f /tmp
```
While running this test, watch the envoy access logs for a permission denied response `"response_code":403`.  The requests to look for are coming from `"user_agent":"fortio.org/fortio-1.54.2"`

## Run All Fortio Tests
The following wrapper scripts use fortio_cli.sh to run a suite of tests.
* `metrics/scripts/seq_fortio_cli_runs.sh`

### Sequencial - seq_fortio_cli_runs.sh
Runs a test case on every fortio namespace

This script will use your current k8s context to discover all fortio test case namespaces.  Each run uses a higher # of concurrent connections or threads (2, 4, 8, 16, 32, 64) unless connection count/s are provided.  The default test duration is 300 seconds per test.
```
seq_fortio_cli_runs.sh -t "tcp" -c16  -d300 -w5 -p1024 -f ./tmp
seq_fortio_cli_runs.sh -t "http" -k usw2-app1 -c16  -d300 -w5 -f ./tmp
```

### Notes
Istio Performance Test
https://istio.io/v1.14/docs/ops/deployment/performance-and-scalability/


#### Fortio Reports
Run Fortio reports command pointing to the output from fortio_cli.sh so graphically see the reports.
```
fortio report -data-dir ./tmp/
```
port-forward 8080:8080 and access reports at localhost:8080/fortio by clicking on `reports`

#### Running Fortio directly from the Pod
fortio-client pod is setup to run the `fortio load` command and target a remote service called `fortio-server-defaults` for http or tcp, and `fortio-server-defaults-grpc` for grpc.  To 

GRPC
```
kubectl exec -it deploy/fortio-client -- fortio load -a -grpc -ping -grpc-ping-delay 0.25s -payload "01234567890" -c 2 -s 4 -json - fortio-server-defaults-grpc:8079

kubectl exec -it deploy/fortio-client -- fortio load -grpc -ping -qps 100 -c 10 -r .0001 -t 3s -labels "grpc test" fortio-server-defaults-grpc:8079

# -s multiple streams per -c connection.  .25s delay in replies using payload of 10bytes
kubectl exec -it deploy/fortio-client -- fortio load -a -grpc -ping -grpc-ping-delay 0.25s -payload "01234567890" -c 2 -s 4 fortio-server-defaults-grpc:8079
```

HTTP - baseline (no mesh)
* `-json -` write json output to stdout
```
kubectl -n fortio-baseline exec -it deploy/fortio-client -- fortio load -qps 1000 -c 16 -r .0001 -t 300s -labels "http test" -json - http://fortio-server-defaults:8080/echo
```

HTTP - consul default (mesh enabled)
```
kubectl -n fortio-consul-default exec -it deploy/fortio-client -- fortio load -qps 1000 -c 16 -r .0001 -t 300s -labels "http test" -json - http://fortio-server-defaults:8080/echo
```

TCP
```
kubectl -n fortio-consul-tcp exec -it deploy/fortio-client -- fortio load -qps -1 -n 100000 tcp://fortio-server-defaults:8078
```

UDP
```
kubectl -n fortio-consul-tcp exec -it deploy/fortio-client -- fortio load -qps -1 -n 100000 udp://fortio-server-defaults:8078/
```

Run fortio HTTP load test directly against pod
```
kubectl exec -it fortio-client-6b78f9c56c-hxzjk -- fortio load -qps 100 -c 10 -r .0001 -t 3s -labels "http test" http://fortio-server-defaults:8080/echo
```

#### Debug with netshoot to see encrypted traffic
##### Get Baseline
```
POD_NAME=$(kubectl -n fortio-baseline get pod -l app=fortio-client -o jsonpath={.items..metadata.name} | cut -d ' ' -f1)
kubectl -n fortio-baseline debug -q -i $POD_NAME --image=nicolaka/netshoot -- \
  tcpdump -l --immediate-mode -vv -s 0 '(((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
```
You should see HTTP Header info like response codes

##### Get Istio/Consul pod
```
POD_NAME=$(kubectl -n fortio-istio-default get pod -l app=fortio-client -o jsonpath={.items..metadata.name} | cut -d ' ' -f1)

kubectl -n fortio-istio-default debug -q -i $POD_NAME --image=nicolaka/netshoot -- \
  tcpdump -l --immediate-mode -vv -s 0 '(((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
```
You should not see any packet data that isn't encrypted

#### curl (add injector)
```
kubectl run -i --rm --restart=Never dummy --image=dockerqa/curl:ubuntu-trusty --command -- curl --silent httpbin:8000/html
```
