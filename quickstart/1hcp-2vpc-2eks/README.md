# Connect 1 HCP Cluster to 2 VPCs with EKS clusters
This repo uses Terraform to setup 1 HCP cluster, 1 shared VPC with bastion host, and 2 VPCs each with an EKS cluster that can be bootstrapped to HCP.  Using the examples directory you can configure HCP Consul, and deploy the fake-service to both EKS clusters demonstrating service to server discovery and routing.

## PreReqs
- Consul Enterprise License copied to `./files/consul.lic` (optional)
- HCP credentials sourced into shell (HCP_CLIENT_ID, HCP_CLIENT_SECRET)
- AWS credentials (with permission to build vpc, transit gateway, ec2, eks, sg)
- Terraform 1.3.7+
- aws cli
- kubectl
- helm
- Consul 1.15.2  (optional)

## Setup
To build all required AWS infrastructure for this environment run terraform from this directory.  Source all required AWS and HCP environment variables into your shell before running terraform.
```
export HCP_CLIENT_ID=
export HCP_CLIENT_SECRET=
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
```

* edit `my.auto.tfvars` and update the AWS key to your keypair.
* edit the locals in `dc-usw2.tf` to change the cidrs in HCP and VPCs as needed.

```
terraform init
terraform apply -auto-approve
```

## Connect to EKS clusters
If using the above terraform connect to EKS using `./scripts/kubectl_connect_eks.sh`.  Pass this script the path to the terraform state file used to provision the infrastructure.  The easiest way to run this script is by staying in the directory where you ran terraform.
```
source ../../scripts/kubectl_connect_eks.sh .
```
This script connects to all EKS clusters and configures useful aliases shown in the output.

## Install AWS EKS Load Balancer Controller
The AWS Load Balancer Controller is required to enable NLBs for both internal and external access.  NLBs are the best way to support Mesh Gateways or any EKS Load balancer resource that requires an internal IP.  The helm chart that will be used next to bootstrap the EKS clusters to Consul will use this controller to allocate an internal NLB for the mesh gateway running on EKS. Pass the directory with the terraform.tfstate file as a parameter.  The easiest way to run this script is by staying in the directory where you ran terraform.
```
../../scripts/install_awslb_controller.sh .
```
This script was written outside of TF to overcome provider limitations and install the controller on multiple EKS clusters at once.  To set this up using terraform refer to comments in `modules/aws_eks_cluster/main.tf`.  If not using the above terraform review the script or AWS documentation to install the AWS LB Controller.

## Install Consul Dataplane in EKS
The terraform above creates a new terraform file for each EKS cluster in `./consul_helm_values`.  Using Terraform deploy the consul dataplane to each remote EKS cluster.  During this terraform run a helm.values file will be generated which can be used for future upgrades, maint, or troubleshooting directly with helm.
```
cd consul_helm_values
init
terraform apply -auto-approve
```
If helm is easier to use initially there are example dataplane.values.yaml in `./examples/apps-2vpc-dataplane-ap-def/helm_examples/` that can be quickly installed directly to your EKS clusters.

### UPDATE: Dataplane with CNI Enabled
After building this solutin with HCP I believe CNI provides a much cleaner DNS solution that is leveraging the dataplanes GRPC port and requires no additional firewall rules or configurations.  Sorry for any confusion here!  I pivoted to enable cni in this repo.

## Login to HCP Consul
If using the terraform above then run the following command from within the terraform directory.  This will update your existing environment with the information required to run consul locally as a CLI tool.
```
source ../../scripts/setHCP-ConsulEnv-usw2.sh .
```
This script will also output the URL and root token you can use to login.

## Deploy fake-service using default namespace
Deploy fake-service to see services running in the mesh.  This deployment script uses fake-service to deploy an instance of `web` into the web-vpc, and an instance of `api` in the api-vpc.  This deployment shows `web` securely discovering and routing requests to `api` across VPCs, and EKS clusters.

The script configures the following:
* service intentions authorizing `web -> api`
* ingress-gateway (deployed with helm) to route to `web` for external access
* proxy-defaults and mesh-defaults for both Consul partitions (aka: EKS clusters).
* exported-services to expose mesh-gateways and services to the consuming partitions.

From the terraform directory run the following command.
```
../../examples/apps-2vpc-dataplane-ap-def/fake-service/deploy.sh
```
The script should output the Ingress URL for web. It might take a couple minutes before being available in DNS.  Once available, the fake service should show `web` accessing its upstream `api` across VPCs and EKS clusters.

## Deploy fake-service into application specific namespaces
Deploy fake-service to see services running in the mesh.  This deployment script uses fake-service to deploy an instance of `web` into the web-vpc, and an instance of `api` in the api-vpc.  This deployment shows `web` securely discovering and routing requests to `api` across k8s namespaces, EKS clusters, and AWS VPCs.

The script configures the following:
* service intentions authorizing `web -> api`
* ingress-gateway (deployed with helm) to route to `web` for external access
* proxy-defaults and service-defaults for both Consul partitions (aka: EKS clusters).
* exported-services to expose mesh-gateways and services to the consuming partitions.

From the terraform directory run the following command.
```
../../examples/apps-2vpc-dataplane-ap-ns/fake-service/deploy.sh
```
The script should output the Ingress URL for web. It might take a couple minutes before being available in DNS.  Once available, the fake service should show `web` accessing its upstream `api` across namespaces, EKS clusters, and VPCs.

## IPTable Rules
Based on our call, I added the `./examples/wbitt-multitool` deployment.  This privilaged container can show the iptables configured by Consul on the node.  Deploy it into the mesh, exec into it to run iptables, and output should look as follows:

```
kubectl apply -f ../../examples/multitool-consul.yaml
kubectl exec -it deploy/network-multitool -- iptables -t nat -L
...

Defaulted container "network-multitool" out of: network-multitool, consul-dataplane, consul-connect-inject-init (init)
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination
CONSUL_PROXY_INBOUND  tcp  --  anywhere             anywhere

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
CONSUL_DNS_REDIRECT  udp  --  anywhere             localhost            udp dpt:domain
CONSUL_DNS_REDIRECT  tcp  --  anywhere             localhost            tcp dpt:domain
CONSUL_PROXY_OUTPUT  tcp  --  anywhere             anywhere

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination

Chain CONSUL_DNS_REDIRECT (2 references)
target     prot opt source               destination
DNAT       udp  --  anywhere             localhost            udp dpt:domain to:127.0.0.1:8600
DNAT       tcp  --  anywhere             localhost            tcp dpt:domain to:127.0.0.1:8600

Chain CONSUL_PROXY_INBOUND (1 references)
target     prot opt source               destination
RETURN     tcp  --  anywhere             anywhere             tcp dpt:20200
CONSUL_PROXY_IN_REDIRECT  tcp  --  anywhere             anywhere

Chain CONSUL_PROXY_IN_REDIRECT (1 references)
target     prot opt source               destination
REDIRECT   tcp  --  anywhere             anywhere             redir ports 20000

Chain CONSUL_PROXY_OUTPUT (1 references)
target     prot opt source               destination
RETURN     all  --  anywhere             anywhere             owner UID match 5996
RETURN     all  --  anywhere             anywhere             owner UID match 5995
RETURN     all  --  anywhere             localhost
CONSUL_PROXY_REDIRECT  all  --  anywhere             anywhere

Chain CONSUL_PROXY_REDIRECT (1 references)
target     prot opt source               destination
REDIRECT   tcp  --  anywhere             anywhere             redir ports 15001
```


