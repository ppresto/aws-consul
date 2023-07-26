# Multi-Region HCP Clusters (us-west-2, us-east-1), EKS clusters, and EC2
This configuration creates 2 HCP clusters in different regions.  Each region has multiple VPCs hosting different services (EKS, EC2).  These VPCs are connected using a local transit gateways.  Finally, the 2 transit gateways are peered across regions with the proper routing configured to allow the Consul service mesh to extend across regions.  

## Pre Reqs
- Consul Enterprise License copied to `./files/consul.lic`
- Setup shell with AWS credentials (need permission to build all networking, ec2, eks, & placement groups)
- Terraform 1.3.7+
- aws cli
- kubectl
- Consul 1.14.6+  (optional)

## Getting Started
First, go to the infrastructure directory and define the admin partition name as a variable.
```
cd quickstart/2hcp-2eks-2ec2
```
edit `my.auto.tfvars` and update the consul_partition to `app1`
```
#consul_partition            = "default"
consul_partition            = "app1"
```

Use terraform to build the infrastructure.  
```
cd quickstart/2hcp-2eks-2ec2
terraform init
terraform apply -auto-approve
```
`Note:`  The first run will probably error out because certain resources like HCP and AWS transit gateways are being created, and the TF provider things its complete, but these resources are not yet ready to be configured.  So updating the tgw with routes, or hcp consul with policies tends to fail.  Rerun the apply should resolve this issue.  If it doesn't wait a minute and rerun again.

### Connect to EKS clusters
Connect to EKS using `./scripts/kubectl_connect_eks.sh`.  Pass this script the path to the terraform state file used to provision the infrastructure.  The easiest way to run this script is by staying in the directory where you ran terraform from (ex: `./2hcp-2eks-2ec2`) and running this command.
```
source ../../scripts/kubectl_connect_eks.sh .
```
This script connects to both EKS clusters and build useful aliases shown in the output.

### Install AWS EKS Load Balancer Controller
The AWS Load Balancer Controller is required to enable NLBs for both internal and external access.  NLBs are the best way to support Mesh Gateways or any EKS Load balancer resource that requires an internal IP.  The helm chart that will be used next to bootstrap the EKS clusters to Consul will use this controller to allocate an internal NLB for the mesh gateway running on EKS. Pass the directory with the terraform.tfstate file as a parameter.  If you are following this guide and already in the directory simply run the command below.
```
../../scripts/install_awslb_controller.sh .
```
This script was written outside of TF to overcome provider limitations and install the controller on multiple EKS clusters at once.  To set this up using terraform refer to `modules/aws_eks_cluster_selfmanaged/aws_lb_controller.tf`

### Install Consul
When building the 2 EKS clusters, terraform generated a new tf config in `./consul_helm_values`.  Using terraform bootstrap both EKS clusters to HCP Consul.
```
cd consul_helm_values
terraform init
terraform apply -auto-approve
```
This should take 2-3 minutes to complete. After installing consul the helm.values.yaml used will be written to ./consul_helm_values/helm/.  This file can be used with helm to manage the deployment, experiment with different configurations, or integrate with your current workflow.

### Access Consul UI
From the directory you created your initial infrastructure run the env scripts to quickly get your Consul URL and bootstrap token for admin access.  This assumes you have an HCP Consul cluster with a public endpoint.  If you only have an internal endpoint ensure you have network access to it, and get that endpoint or update the script to pull it.
* CONSUL_HTTP_ADDR
* CONSUL_HTTP_TOKEN
```
source ../../scripts/setHCP-ConsulEnv-usw2.sh  .
```
Open a tab on your browser, cut/paste the URL, and login to the us-west-2 HCP Consul UI with the token.  

Now do the same thing for your other cluster.
```
source ../../scripts/setHCP-ConsulEnv-use1.sh  .
```
Open a new tab on your browser for us-east-1, cut/paste that URL, and login to the HCP Consul UI with the us-east-1 token

## Deploy fake-service
Deploy fake-service to see services running in your mesh.  This deployment script uses fake-service to deploy an instance of `web` and `api` in both regions.  The script configures the intentions allowing `web -> api`, and the ingress gateway (that was deployed as part of the helm chart) so you can access web from outside the mesh. It will also configure proxy and mesh defaults for both Consul clusters to ensure they are configured the same.
```
cd ../../  # Go to the repo base dir
examples/apps-peer-server-def-def/fake-service/deploy-fakeservice-to-usw2-and-use1.sh
```
The script should output URLs for services running in both the west and east datacenter.  Open each of these in their own browser tab to access `web` through the ingress gateway and see its upstream `api` (`ingressgw -> web -> api`).  Verify the services in the West are working and show  the labels `web-west -> api-west`.  These services are configured to failover to the east and will be used later.

## Configure Mesh Defaults
If you deployed fake-service above then skip to the next section. If you didn't deploy the fake-service above then you need to configure the mesh defaults for both HCP Consul clusters. The mesh defaults can only be configured in HCP Consul's default partition.  This configuration controls how Consul Partitions will communicate across regions (aka: HCP Consul data centers).  Configure the mesh defaults to only allow partitions to communicate through their local mesh gateways for a more secure design.  Configure both EKS clusters the same.
```
#us-west-2 EKS cluster
kubectl config use-context usw2-app1
kubectl apply -f examples/apps-peer-server-def-def/fake-service/westus2/init-consul-config/mesh.yaml

#us-east-1 EKS cluster
kubectl config use-context use1-app1
kubectl apply -f examples/apps-peer-server-def-def/fake-service/eastus/init-consul-config/mesh.yaml
```

## Peer HCP Consul Data Centers (us-east-1 to us-west-2)
The script assumes `kubectl_connect_eks.sh` was used to authenticate to both EKS clusters, and that the infrastructure was built in `quickstart/2hcp-2eks-2ec2` which contains the current terraform state.  The script will do the following:
1. Use K8s CRDs to configure the Peering connection
2. Create a Peering Acceptor (us-east-1) which will create a secret with the CA, MGW location, and token
3. Output the Acceptor K8s secret for visibility
4. Copy the Acceptor secret to the Peering Dialer (us-west-2) which needs this to establish a connection
5. Create a Peering Dialer (us-west-2) using the secret
6. Verify the Peering Connection on the Acceptor using the API
7. Export the `api` service from us-east-1 to us-west-2 using the peering connection.
```
examples/apps-peer-server-def-def/peering/peer_east_to_west.sh
```
If the Peering stays in a `PENDING` state there is most likely a L3 network connectivity problem.  Check the Troubleshooting section.  If you see an `ACTIVE` state then the Peering was successful.  Go to the left panel for both HCP Consul data centers and click on `Peers` for more information.

### Test Regional Failover
The script tat created the Peering connection exported the `api` service from the peer in us-east-1 to us-west-2. Look in the West HCP Consul UI and the imported `api` service should be visible.  If not reload the page.  After verifying the imported service is healthy, verify failover is setup.

```
cat examples/apps-peer-server-def-def/fake-service/westus2/api-service-resolver.yaml
```
The deploy script already applied this service resolver.  You can verify this is setup using the West HCP COnsul UI.  Go to `Services -> api` and make sure you click on the local api service not the imported one.  The local api service will give you multiple tabs on the top for additional information.  Select `Routing` and you should see the peering failover target with the peering name.  This is present in the Resolvers box represented using a cloud with an X.  Now lets delete the `api` service running in the west and watch it failover to the peer in the east that is running the same `api` service.

```
kubectl config use-context usw2-app1
kubectl delete -f examples/apps-peer-server-def-def/fake-service/westus2/api.yaml
kubectl get pods
```
The `api` service should no longer be running in the west.  Now reload the browser tab for the `web-west` service.  The upstream should automatically route to the `api-east` service and the IP will be from a differnt CIDR.  The web-west service automatically routed to its failover target (the East data center) when its local service was unavailable.

### Tail HCP Consul Logs using the CLI
Setup your environment by going to the dir with the terraform state file and sourcing the following script.
```
cd quickstart/2hcp-2eks-2ec2
source ../../scripts/setHCP-ConsulEnv-usw2.sh .

# tail logs
CONSUL_HTTP_SSL_VERIFY=false consul monitor -log-level debug -token ${CONSUL_HTTP_TOKEN} http-addr ${CONSUL_HTTP_ADDR//https:\/\/}
```
Using the domain name of your HCP Consul cluster will give you a random instance.  To tail all instances lookup the dns record `dig +short ${CONSUL_HTTP_ADDR//https:\/\/}`  and run the above command against all the IPs individually in different tabs.

## Clean Up
Remove the Peering, fake-services, and Consul dataplanes from EKS for a clean environment.
```
examples/apps-peer-server-def-def/peering/peer_east_to_west.sh destroy
examples/apps-peer-server-def-def/fake-service/deploy-fakeservice-to-usw2-and-use1.sh destroy
cd consul_helm_values
terraform destroy -auto-approve
```