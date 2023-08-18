# Deploy Services, Terminating GW, and show encryption

## PreReq
* Build TF Infra `./quickstart/1hcp-2vpc-2eks`
* Install AWS LB Controller `../../scripts/install_awslb_controller.sh .`
* Connect to eks clusters from TF directory `../../scripts/kubectl_connect_eks.sh .`
* Setup local Consul Env`source ../../scripts/setConsul.sh .`
## Quickstart
skip steps below for a fully running environment
```
./examples/apps-dataplane-tgw-ap-def/deploy.sh
```
## HCP / Consul UI
Explain Partitions
* Default/Default - 3 Consul Servers
* Web/Default - Onboarding first EKS cluster to partition `web`

## Deploy Services to Web
Use CLI or K9s and review EKS cluster before deploying services
```
web1
kubectl -n web get po
kubectl -n api get po
```

Deploy web and api services to the first EKS cluster
```
./examples/apps-dataplane-tgw-ap-def/fake-service/web/deploy.sh
```
* Review Pods in both namespaces
* Review Consul Namespaces in the UI
* Go to fake-service URL

### Verify Encryption
`web->api` traffic will go through the envoy sidecar which sends traffic on port 20000.  Verify the traffic is encrypted by attaching a debug container (nicolaka/netshoot) to the dataplane sidecar on the source service `web`.  The following tcpdump command will look at outgoing traffic on the default envoy port 20000.
```
tcpdump tcp and src $(hostname -i) and dst port 20000 -A
```
attach debug container: `kubectl debug -it --context web1 -n web $POD --target consul-dataplane --image nicolaka/netshoot`

## Bootstrap the 2nd EKS Cluster to HCP and deploy the `api` service
Run the helm install if the dataplane is not already installed.  Deploy services in the new partition `api`.

```
./examples/apps-dataplane-tgw-ap-def/fake-service/api/deploy.sh
./examples/apps-dataplane-tgw-ap-def/fake-service/web-final/deploy.sh  #redeploy web to point to new api svc now.
```
* Review the EKS cluster
* Review the new Consul Partition in the UI

## Walk through terminating GW setup
The new EKS cluster will deploy a service called `api` that's authorized to make external requests to example.com
```
/examples/apps-dataplane-tgw-ap-def/terminating-gw-example.com/
```
* servicedefaults.yaml
* terminating-gw.yaml
* intentions.yaml

## Redeploy `web` to point to the new `api` service to validate example.com
```
./examples/apps-dataplane-tgw-ap-def/fake-service/web-final/deploy.sh
```

## Clean up
```
./examples/apps-dataplane-tgw-ap-def/deploy.sh -d
```