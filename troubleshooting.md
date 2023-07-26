<!-- TOC -->

- [Troubleshooting](#troubleshooting)
  - [Transit Gateway](#transit-gateway)
  - [SSH - Bastion Host](#ssh---bastion-host)
    - [Manually create SSH Key, and AWS keypair](#manually-create-ssh-key-and-aws-keypair)
  - [AWS EC2 / VM](#aws-ec2--vm)
    - [AWS EC2 - Helpful Commands](#aws-ec2---helpful-commands)
    - [AWS EC2 - Review Cloud-init execution](#aws-ec2---review-cloud-init-execution)
    - [AWS EC2 - systemctl consul.service](#aws-ec2---systemctl-consulservice)
    - [AWS EC2 - logs](#aws-ec2---logs)
    - [AWS EC2 - Register local service with API](#aws-ec2---register-local-service-with-api)
    - [ESM - Install](#esm---install)
    - [ESM - Register external service](#esm---register-external-service)
    - [AWS EC2 - Test client connectivity to HCP Consul](#aws-ec2---test-client-connectivity-to-hcp-consul)
    - [AWS EC2 - Monitor the Server](#aws-ec2---monitor-the-server)
    - [AWS EC2 - Deploy service (api)](#aws-ec2---deploy-service-api)
  - [Consul - DNS](#consul---dns)
    - [Consul - DNS lookups with agent](#consul---dns-lookups-with-agent)
    - [Consul - DNS lookups on EKS](#consul---dns-lookups-on-eks)
    - [Consul - Mesh GW](#consul---mesh-gw)
    - [Consul - Ingress GW](#consul---ingress-gw)
    - [Consul - DNS Forwarding](#consul---dns-forwarding)
    - [Consul - Deregister Node from HCP.](#consul---deregister-node-from-hcp)
    - [Consul - Connect CA](#consul---connect-ca)
    - [Consul - Admin Partitions.](#consul---admin-partitions)
  - [EKS / Kubernetes](#eks--kubernetes)
    - [EKS - Login / Set Context](#eks---login--set-context)
    - [EKS - Install Consul with Helm](#eks---install-consul-with-helm)
    - [EKS - Uninstall Helm chart](#eks---uninstall-helm-chart)
    - [EKS - Helm install AWS LB Controller](#eks---helm-install-aws-lb-controller)
    - [EKS - Test pod connectivity to Consul](#eks---test-pod-connectivity-to-consul)
    - [EKS - DNS Troubleshooting](#eks---dns-troubleshooting)
    - [EKS - Change proxy global defaults](#eks---change-proxy-global-defaults)
    - [EKS - Terminate stuck namespace](#eks---terminate-stuck-namespace)
    - [EKS - Terminate stuck objects](#eks---terminate-stuck-objects)
  - [Envoy](#envoy)
    - [Attach debug container to pod to run additional commands (tcpdump, netstat, dig, curl, etc...)](#attach-debug-container-to-pod-to-run-additional-commands-tcpdump-netstat-dig-curl-etc)
    - [Envoy - Change logging level](#envoy---change-logging-level)
    - [Envoy - Read fake-service envoy-sidcar configuration](#envoy---read-fake-service-envoy-sidcar-configuration)
  - [Metrics](#metrics)
    - [Prometheus](#prometheus)
    - [Deploy Grafana Notes](#deploy-grafana-notes)
  - [Load Testing | Fortio](#load-testing--fortio)
  - [Troubleshooting](#troubleshooting-1)
    - [HCP Logs](#hcp-logs)
    - [Peering](#peering)

<!-- /TOC -->
# Troubleshooting

## Transit Gateway
* VPCs need unique IP ranges unless using a mesh gateways across consul data centers.
* Review VPC Route Table and ensure the TGW is set as a target to all Destinations that need access to HCP
* [AWS TGW Troubleshooting Guide](https://aws.amazon.com/premiumsupport/knowledge-center/transit-gateway-fix-vpc-connection/)
* [Hashicorp TGW UI Setup Video](https://youtu.be/tw7FK_uUwqI?t=527
https://learn.hashicorp.com/tutorials/cloud/amazon-transit-gateway?in=consul/)
* [Visual Subnet Calculator](https://www.davidc.net/sites/default/subnets/subnets.html?network=10.0.0.0&mask=20&division=23.f42331) to help find the correct CIDR block ranges.

## SSH - Bastion Host
SSH to bastion host for access to internal networks.  The TF is leveraging your AWS Key Pair for the Bastion/EC2 and EKS nodes.  Use `Agent Forwarding` to ssh to your nodes.  Locally in your terminal find your key and setup ssh.
```
ssh-add -L  # Find SSH Keys added
ssh-add ${HOME}/.ssh/hcp-consul  # If you dont have any keys then add your key being used in TF.
ssh -A ubuntu@<BASTION_IP>  # pass your key in memory to the ubuntu Bastion Host you ssh to.
ssh -A ec2_user@<K8S_NODE_IP> # From bastion use your key to access a node in the private network.
ssh -A -J ubuntu@<PUBLIC_BASTION_IP> ubuntu@<PRIVATE_EC2_IP>
```

### Manually create SSH Key, and AWS keypair
```
ssh-keygen -t rsa -b 4096 -f /tmp/hcp-consul -N ''
publickeyfile="/tmp/tfc-hcpc-pipelines/hcp-consul.pub"
aws_keypair_name=my-aws-keypair-$(date +%Y%m%d)
echo aws ec2 import-key-pair \
    --region "$AWS_DEFAULT_REGION" \
    --key-name "$aws_keypair_name" \
    --public-key-material "fileb://$publickeyfile"
```

## AWS EC2 / VM

### AWS EC2 - Helpful Commands

SSH through public bastion host to internal VM
```
ssh -A -J ubuntu@54.202.45.196 ubuntu@10.17.1.130
```

SCP consul-ca-cert through public bastion from K8s cluster to an internal VM.
```
scp -o 'ProxyCommand ssh ubuntu@54.202.45.196 -W %h:%p' ./ca.pem ubuntu@10.17.1.130:/tmp/ca.pem
```

Get K8s Consul secrets
```
kubectl -n consul get secret consul-ca-cert --context consul1 -o json | jq -r '.data."tls.crt"' | base64 -d > ca.pem
kubectl -n consul get secrets consul-gossip-encryption-key -o jsonpath='{.data.key}'| base64 -d
```

Generate AWS kubeconfig file for VM (`cluster-name: presto-usw2-consul1`)
```
aws eks --region us-west-2 update-kubeconfig --name presto-usw2-consul1 --kubeconfig ./kubeconfig
```

### AWS EC2 - Review Cloud-init execution
When a user data script is processed, it is copied to and run from /var/lib/cloud/instances/instance-id/. The script is not deleted after it is run and can be found in this directory with the name user-data.txt.  
```
sudo cat /var/lib/cloud/instance/user-data.txt
```
The cloud-init log captures console output of the user-data script run.
```
sudo cat /var/log/cloud-init-output.log
```

### AWS EC2 - systemctl consul.service
This repo creates the systemd start script located at `/etc/systemd/system/consul.service`.  This scripts requires:
*  /opt/consul to store data.
*  /etc/consul.d/certs - ca.pem from HCP
*  /etc/consul.d/ - HCP default configs and an ACL token

To stop, start, and get the status of the service
```
sudo systemctl stop consul.service
sudo systemctl start consul.service
sudo systemctl status consul.service
```

### AWS EC2 - logs
To investigate systemd errors starting consul use `journalctl`.  
```
journalctl -u consul -xn | less
```
pipe to less to avoid line truncation in terminal

### AWS EC2 - Register local service with API
web.json
```
{
  "id": "web1",
  "name": "web",
  "port": 80,
  "token": "$TOKEN",
  "tags": ["vm","v1"],
  "check": {
    "name": "ping check",
    "args": ["ping", "-c1", "learn.hashicorp.com"],
    "interval": "30s",
    "status": "passing"
  }
}
```

Regster using API endpoint /agent/service/register #avoid CLI permission bug
```
curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT --data @web.json localhost:8500/v1/agent/service/register
sleep 2
curl localhost:8500/v1/catalog/service/web | jq -r
curl localhost:8500/v1/agent/checks | jq -r
```
deregister with service-id (web1)
```
curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT localhost:8500/v1/agent/service/deregister/web1
```
deregister node
```
curl --silent --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT --data '{"Datacenter": "dc1","Node": "consul-server-0","ServiceID": "consul-esm:"}' localhost:8500/v1/catalog/deregister
```
### ESM - Install
```
VERSION="0.7.1"
sudo wget https://releases.hashicorp.com/consul-esm/${VERSION}/consul-esm_${VERSION}_linux_386.zip
sudo unzip consul-esm_${VERSION}*.zip
sudo rm *.zip
```
### ESM - Register external service

external.json
```
{
  "Node": "hashicorp",
  "Address": "learn.hashicorp.com",
  "NodeMeta": {
    "external-node": "true",
    "external-probe": "true"
  },
  "Service": {
    "ID": "learn1",
    "Service": "learn",
    "Port": 80
  },
  "Checks": [
    {
      "Name": "http-check",
      "status": "passing",
      "Definition": {
        "http": "https://learn.hashicorp.com/consul/",
        "interval": "30s"
      }
    }
  ]
}
```
Regster External svc using endpoing: /catalog/register
```
curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request PUT --data @external.json localhost:8500/v1/catalog/register
sleep 2
curl localhost:8500/v1/catalog/service/learn | jq -r
```


### AWS EC2 - Test client connectivity to HCP Consul
First check consul logs above to verify the local client successfully connected.  You should see the IP of the node and `agent: Synced`
```
[INFO]  agent: Synced node info
```
If the client can't connect verify it has a route to HCP Consul's internal address and the required ports.
```
ssh ubuntu@**bastion_ip**   #terraform output variable
consul_url=**consul_private_endpoint_url**   #terraform output variable

curl ${consul_url}/v1/status/leader  #verify consul internal url is accessible and service healthy
ip=$(dig +short ${consul_url//https:\/\/}) # get internal consul IP
ping $ip
nc -zv $ip 8301   # TCP Test to remote HCP Consul agent port
nc -zvu $ip 8301  # UDP 8301
nc -zv $ip 8300   # TCP 8300
```

Look at the logs to identify other unhealthy clients in remote VPC's.
```
[INFO]  agent.client.serf.lan: serf: EventMemberFailed: ip-10-15-2-242.us-west-2.compute.internal 10.15.2.79
[INFO]  agent.client.memberlist.lan: memberlist: Suspect ip-10-15-2-242.us-west-2.compute.internal has failed, no acks received
```
These are examples of a client that can connect to HCP Consul, but not all other agents in other VPC's that are using the shared service.  Unless they are in their own Admin Partition they need to be able to route to all other agents participating in HCP Consul. This is how Consul agents monitor each other through Gossip.  In this case, verify both source and destinations can reach eachother over TCP and UDP on port 8301.
```
nc -zv 10.15.2.79 8301
nc -zvu 10.15.2.79 8301
```

Check Security group rules to ensure TCP/UDP bidirectional traffic is openned to all networks using HCP.  
Warning:  EKS managed nodes are mapped to specific security groups that need to allow this traffic.  Refer to `aws_eks/sg-hcp-consul.tf`
### AWS EC2 - Monitor the Server
Using the consul client with the root token get a live stream of logs from the server.
```
consul monitor -log-level debug
```
### AWS EC2 - Deploy service (api)
The start.sh should start the fake-service, register it to consul as 'api', and start the envoy sidecar.  If this happens before the consul client registers the EC2 node to consul then you may need to restart the service, or look at the logs.
```
cd /opt/consul/fake-service
sudo ./stop.sh
sudo ./start.sh
cat api-service.hcl   # review service registration config
ls ./logs             # review service and envoy logs
```
There are some additional example configurations that use the CLI to configure L7 traffic management.

## Consul - DNS

### Consul - DNS lookups with agent
Use the local consul clients DNS interface that runs on port 8600 for testing.  This client will service local DNS requests to the HCP Consul service over port 8301 so there is no need to add additional security rules for port 8600.
```
dig @127.0.0.1 -p 8600 consul.service.consul

; <<>> DiG 9.11.3-1ubuntu1.17-Ubuntu <<>> @127.0.0.1 -p 8600 consul.service.consul
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 47609
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;consul.service.consul.		IN	A

;; ANSWER SECTION:
consul.service.consul.	0	IN	A	172.25.20.205

;; Query time: 2 msec
;; SERVER: 127.0.0.1#8600(127.0.0.1)
;; WHEN: Tue Aug 16 21:00:13 UTC 2022
;; MSG SIZE  rcvd: 66
```
The response should contain *ANSWER: 1* for a single node HCP development cluster.  If you receive a response with *ANSWER: 0 and status: NXDOMAIN* then most likely you need to [review the DNS policies associated with your consul client](https://learn.hashicorp.com/tutorials/consul/access-control-setup-production?in=consul/security#token-for-dns). In this guide the terraform (./hcp_consul/consul-admin.tf) is creating this policy and assigning it to the anonymous token to allow DNS lookups to work by default for everyone.

Additional DNS Queries
```
dig @127.0.0.1 -p 8600 api.service.consul SRV  # lookup api service IP and Port
```
References:
https://learn.hashicorp.com/tutorials/consul/get-started-service-discover
https://www.consul.io/docs/discovery/dns#dns-with-acls

### Consul - DNS lookups on EKS
Test coredns, start busybox, and use nslookup

```
consuldnsIP=$(kubectl -n consul get svc consul-dns -o json | jq -r '.spec.clusterIP')
corednsIP=$(kubectl -n kube-system get svc kube-dns -o json | jq -r '.spec.clusterIP')
kubectl run busybox --restart=Never --image=busybox:1.28 -- sleep 3600
kubectl exec busybox -- nslookup kubernetes $corednsIP
```

Additional examples:
```
kubectl exec busybox -- nslookup consul.service.consul
kubectl exec busybox -- nslookup api.service.az1.ns.default.ap.aks1-westus2.dc.consul
kubectl exec busybox -- nslookup api.virtual.az1.ns.default.ap.aks1-westus2.dc.consul
```
Additional Info:
https://aws.amazon.com/premiumsupport/knowledge-center/eks-dns-failure/

### Consul - Mesh GW
Connect to mesh gateway by attaching a debug container to the pod
```
kc debug presto-usw2-app1-mesh-gateway-6b48fd8cb9-fmq5w -it --image alpine
apk add openssl
openssl s_client -showcerts -connect 10.15.2.155:8443
```
Add openssl package to verify an https endpoint.

netshoot has many utilities including openssl.
```
kc debug presto-usw2-app1-mesh-gateway-6b48fd8cb9-k4v2r -it --image nicolaka/netshoot
```
### Consul - Ingress GW
```
kubectl -n consul exec deploy/team1-ingress-gateway -c ingress-gateway -- wget -qO- 127.0.0.1:19000/clusters?format=json

kubectl -n consul exec deploy/team1-ingress-gateway -c ingress-gateway -- wget -qO- http://localhost:19000/config_dump

kubectl -n consul exec deploy/team1-ingress-gateway -c ingress-gateway -- wget -qO- 127.0.0.1:19000/config_dump | jq '[.. |."dynamic_route_configs"? | select(. != null)[0]]'

kubectl -n consul exec deploy/team1-ingress-gateway -c ingress-gateway -- wget -qO- http://localhost:8080

kubectl -n consul exec -it deploy/team1-ingress-gateway -c ingress-gateway -- wget --no-check-certificate -qO- http://web.virtual.consul
```
### Consul - DNS Forwarding
Once DNS lookups are working through the local consul client,  setup DNS forwarding to port 53 to work for all requests by default.
https://learn.hashicorp.com/tutorials/consul/dns-forwarding

### Consul - Deregister Node from HCP.
```
curl \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    --request PUT \
    --data '{"Datacenter": "usw2","Node": "ip-10-15-3-83.us-west-2.compute.internal"}' \
    https://usw2.private.consul.328306de-41b8-43a7-9c38-ca8d89d06b07.aws.hashicorp.cloud/v1/catalog/deregister
```
### Consul - Connect CA
```
curl -s ${CONSUL_HTTP_ADDR}/v1/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -text -noout
```
### Consul - Admin Partitions.

Consul CLI to generate peering token
```
consul peering generate-token -partition=eastus-shared -name=consul1-westus2 -server-external-addresses=1.2.3.4:8502 -token "${CONSUL_HTTP_TOKEN}"
```

Consul CLI to delete peeering
```
consul peering delete -name=presto-cluster-usw2 -partition=test -token "${CONSUL_HTTP_TOKEN}"

curl -sk --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
--request DELETE ${CONSUL_HTTP_ADDR}/v1/peering/presto-cluster-usw2
```

Setup: https://github.com/hashicorp/consul-k8s/blob/main/docs/admin-partitions-with-acls.md

Setup K8s Video: https://www.youtube.com/watch?v=RrK89J_pzbk

Blog: https://www.hashicorp.com/blog/achieving-multi-tenancy-with-consul-administrative-partitions
## EKS / Kubernetes

### EKS - Login / Set Context
Login to team1 and set alias 'team1' to current-context
```
aws_team1_eks/connect.sh
export team1_context=$(kubectl config current-context)
alias 'team1=kubectl config use-context $team1_context'
```

Login to team2 and set alias 'team2' to current-context
```
aws_team2_eks/connect.sh
export team2_context=$(kubectl config current-context)
alias 'team2=kubectl config use-context $team2_context'
```

Set default Namespace in current context
```
kubectl config set-context --current --namespace=consul
```

Switch Contexts using team aliases
```
team1
team2
```

Label node
```
kubectl label nodes ip-10-16-1-177.us-west-2.compute.internal nodetype=consul
```
### EKS - Install Consul with Helm
Manually install consul using Helm.  The test.yaml below can be created from existing Terraform Output.  Make sure you are using a [compatable consul-k8s helm chart version](https://www.consul.io/docs/k8s/compatibility).  For Ent Consul make sure you create the k8s license secret in the correct namespace that the helm chart is expecting (ex: consul).

```
kubectl create namespace consul
secret=$(cat ../../files/consul.lic)
kubectl -n consul create secret generic consul-ent-license --from-literal="key=${secret}"

# Copy consul-ca-cert from consul server to dataplane.
kubectl -n consul get secret consul-ca-cert --context consul1 -o yaml | kubectl apply --context app2 -f -

# Copy consul-bootstrap-acl-token from consul server to dataplane.
kubectl -n consul get secret consul-bootstrap-acl-token --context consul1 -o yaml | kubectl apply --context app2 -f -
```

Install Consul Ent
```
helm repo add hashicorp https://helm.releases.hashicorp.com

# 0.43.0 , consul 1.14.3-ent
helm install team2 hashicorp/consul --namespace consul --version 1.0.2 --set global.image="hashicorp/consul-enterprise:1.14.3-ent" --values ./yaml/test.yaml

# 1.0.2 , consul 1.14.4-ent
helm install consul-usw2-app1 hashicorp/consul --namespace consul --version 1.0.2 --values ./yaml/auto-consul-usw2-app2-values.yaml

# Upgrade

RELEASE=$(helm -n consul list -o json | jq -r '.[].name')
helm upgrade ${RELEASE} hashicorp/consul --namespace consul --values ./yaml/auto-consul-auto-${RELEASE}-values-server-sd.yaml

```

### EKS - Uninstall Helm chart
Use consul-k8s cli to `cleanly` uninstall the consul dataplane, client, or server.
```
consul-k8s uninstall -auto-approve -wipe-data
```

The Helm release name must be unique for each Kubernetes cluster. The Helm chart uses the Helm release name as a prefix for the ACL resources that it creates so duplicate names will overwrite ACL's.

[Uninstall Consul / Helm](https://www.consul.io/docs/k8s/operations/uninstall)

### EKS - Helm install AWS LB Controller
```
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=presto-usw2-app1 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```
### EKS - Test pod connectivity to Consul

Run multitool and exec into it
```
kubectl run multitool --image=praqma/network-multitool
kubectl exec -it multitool -- bash
```

Get the IP Address of the Consul Server.  Use netcat to verify if the TCP port is open from EKS.
```
nc -v 172.25.21.116 8502
```

### EKS - DNS Troubleshooting
Get DNS services (consul and coredns), start busybox, and use nslookup
```
consuldnsIP=$(kubectl -n consul get svc consul-dns -o json | jq -r '.spec.clusterIP')
corednsIP=$(kubectl -n kube-system get svc kube-dns -o json | jq -r '.spec.clusterIP')
kubectl run busybox --restart=Never --image=busybox:1.28 -- sleep 3600
kubectl exec busybox -- nslookup kubernetes $corednsIP
```

Test coredns config
```
kubectl run busybox --restart=Never --image=busybox:1.28 -- sleep 3600
kubectl exec busybox -- nslookup kubernetes $corednsIP
```
Test consul config
```
kubectl exec busybox -- nslookup web
kubectl exec busybox -- nslookup web.default  #default k8s namespace
kubectl exec busybox -- nslookup web.service.consul $consuldnsIP
kubectl exec busybox -- nslookup web.ingress.consul #Get associated ingress GW
kubectl exec busybox -- nslookup api.service.consul
kubectl exec busybox -- nslookup api.virtual.consul #Tproxy uses .virtual not .service lookup
```

Additional DNS Queries
```
# Service Lookup for defined upstreams
kubectl exec busybox -- nslookup api.service.api.ns.default.ap.usw2.dc.consul
Name:      api.service.api.ns.default.ap.usw2.dc.consul
Address 1: 10.15.1.175 10-15-1-175.api.api.svc.cluster.local
Address 2: 10.20.1.31 ip-10-20-1-31.us-west-2.compute.internal

# Virtual lookup for Transparent Proxy upstreams
kubectl exec busybox -- nslookup api.virtual.api.ns.default.ap.usw2.dc.consul
Name:      api.virtual.api.ns.default.ap.usw2.dc.consul
Address 1: 240.0.0.3
```
References:
https://aws.amazon.com/premiumsupport/knowledge-center/eks-dns-failure/

### EKS - Change proxy global defaults
For proxy global default changes to take affect restart envoy sidecars with rolling deployment.
```
for i in  $(kubectl get deployments -l service=fake-service -o name); do kubectl rollout restart $i; done
```

### EKS - Terminate stuck namespace

Start proxy on localhost:8001
```
kubectl proxy
```

Use k8s API to delete namespace
```
cat <<EOF | curl -X PUT \
  localhost:8001/api/v1/namespaces/payments/finalize \
  -H "Content-Type: application/json" \
  --data-binary @-
{
  "kind": "Namespace",
  "apiVersion": "v1",
  "metadata": {
    "name": "payments"
  },
  "spec": {
    "finalizers": null
  }
}
EOF
```

Find finalizers in "spec"
```
kubectl get namespace payments -o json > temp.json
```

```
"spec": {
        "finalizers": []
    }
```

### EKS - Terminate stuck objects
Examples to Fix defaults, intentions, and ingressgateways that wont delete
```
kubectl patch servicedefaults.consul.hashicorp.com payments -n payments --type merge --patch '{"metadata":{"finalizers":[]}}'
kubectl patch servicedefaults.consul.hashicorp.com web -n consul --type merge --patch '{"metadata":{"finalizers":[]}}'

kubectl patch serviceresolvers.consul.hashicorp.com api -n api --type merge --patch '{"metadata":{"finalizers":[]}}'

kubectl patch ingressgateway.consul.hashicorp.com ingress-gateway --type merge --patch '{"metadata":{"finalizers":[]}}'

kubectl patch serviceintentions.consul.hashicorp.com payments --type merge --patch '{"metadata":{"finalizers":[]}}'

kubectl patch exportedservices.consul.hashicorp.com pci -n default --type merge --patch '{"metadata":{"finalizers":[]}}'

kubectl patch proxydefaults.consul.hashicorp.com global -n default --type merge --patch '{"metadata":{"finalizers":[]}}'
```

## Envoy
[Verify Envoy compatability](https://www.consul.io/docs/connect/proxies/envoy) for your platform and consul version.

### Attach debug container to pod to run additional commands (tcpdump, netstat, dig, curl, etc...)
```
kubectl -n fortio-baseline debug -it $POD_NAME --image=nicolaka/netshoot
#kubectl -n fortio-baseline debug -q -i $POD_NAME --image=nicolaka/netshoot
```

### Envoy - Change logging level

Change mesh gateway logging level to Trace
```
kubectl port-forward mesh-gateway-pod-name 19000:19000
curl -X POST http://localhost:19000/logging?level=trace
```

Output mgw logs and new entries will show trace level
```
kubectl logs mesh-gateway-pod-name > mgw.trace.log
```
### Envoy - Read fake-service envoy-sidcar configuration
kubectl exec deploy/web -c envoy-sidecar -- wget -qO- localhost:19000/clusters
kubectl exec deploy/api-deployment-v2 -c envoy-sidecar -- wget -qO- localhost:19000/clusters
kubectl exec deploy/api-deployment-v2 -c envoy-sidecar -- wget -qO- localhost:19000/config_dump

NetCat - Verify IP:Port connectivity from EKS Pod
```
kubectl exec -it deploy/web  -c web -- nc -zv 10.20.11.138 21000
kubectl exec -it deploy/web  -c envoy-sidecar -- nc -zv 10.20.11.138 20000
```

List fake-service pods across all k8s ns
```
kubectl get pods -A -l service=fake-service
```

Using Manually defined upstreams (web -> api). the service dns lookup can be used to discover these services (api.service.consul, or api.default in single k8s cluster)
```
kubectl exec -it $(kubectl get pod -l app=web -o name) -c web -- curl http://localhost:9090
kubectl exec -it $(kubectl get pod -l app=web -o name) -c web -- curl http://localhost:9091
```

Using Transparent Proxy upstreams (web -> api).
* web runs in the usw2 DC, default AP, in the web namespace.
* api runs in the usw2 DC, default AP, in the api namespace.

Verify api intentions are correct, and that the web proxy has discovered api upstreams.
```
kubectl -n web exec web -c envoy-sidecar -- wget -qO- 127.0.0.1:19000/clusters

api.api.usw2.internal.b61b8e34-30b1-5058-9f49-5ca6f80c645a.consul::10.15.1.175:20000::health_flags::healthy
api.api.usw2.internal.b61b8e34-30b1-5058-9f49-5ca6f80c645a.consul::10.20.1.31:20000::health_flags::healthy
```

Next test the web app container can use the virtual lookup to connect to the api upstream.
```
kubectl -n web exec deploy/web -c web -- wget -qO- http://api.virtual.api.ns.default.ap.usw2.dc.consul
```
## Metrics
Refer to the METRICS.md for more details.

### Prometheus
Refer to the PROMETHEUS.md for more details.

To Manually deploy metrics tools to the Metrics nodes of the EKS cluster using nodeSelector `nodetype=default` follow these notes.
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install -f deploy/helm/prometheus-values.yaml prometheus prometheus-community/prometheus --version "15.5.3" --wait
helm install prometheus-consul-exporter prometheus-community/prometheus-consul-exporter --set nodeSelector.nodetype=default --wait
```
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
`prometheus-server.default.svc.cluster.local`

Get the Prometheus server URL by running these commands in the same shell:
```
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 9090 &
```

Get the PushGateway URL by running these commands in the same shell:
```
export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus,component=pushgateway" -o jsonpath="{.items[0].metadata.name}") 
kubectl --namespace default port-forward $POD_NAME 9091 &
```

### Deploy Grafana Notes
Manual deployment steps
```
helm repo add grafana https://grafana.github.io/helm-charts
helm install -f deploy/helm/grafana-values.yaml grafana grafana/grafana --wait
helm install -f deploy/helm/grafana-values.yaml grafana grafana/grafana --set nodeSelector.nodetype=default --wait
```

Grafana URL to visit by running these commands in the same shell:
```
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 3000 &
```
Login (admin/passwword)

## Load Testing | Fortio
Refer to METRICS.md
## Troubleshooting

### HCP Logs
```
# Get consul cluster (all servers) IPs using nslookup
nslookup $CONSUL_HTTP_ADDR #domain only remove https://
# Open 3 tabs, create token, and issue monitor command on each IP to tail logs
CONSUL_HTTP_SSL_VERIFY=false consul monitor -log-level debug -token xxxx -http-addr https://35.166.37.150
```

### Peering

Confirm the usw2 EKS cluster can access the use1 EKS Cluster service `api`.
```
source ../../scripts/setHCP-ConsulEnv-usw2.sh  .

kubectl exec -it deploy/web -- curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/health/connect/api?peer=presto-cluster-use1-default | jq -r

kubectl exec -it deploy/web -- curl --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/health/connect/api?peer=presto-cluster-use1-default | jq '.[].Service.ID,.[].Service.PeerName
```
output contains the `api` sidecar service ID and the name of the related cluster peering.
