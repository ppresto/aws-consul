# AWS-Consul

This repo builds the required AWS Networking and EKS resources to run either self hosted or HCP Consul using a variety of different single or multi datacenter architectures. It includes working examples to provision AWS infrastructure, configure Consul, gathering metrics, and run performance test with Fortio.

## Getting Started
Review the different architecture models within ./quickstart.  There are more details on these at the bottom of this README.  Some use HCP, some are self hosted, and the example covered below is a self hosted model using placement groups and nodegroups.  All models use a similar build workflow that's described below and have a Makefile that can be used to build every stage of the environment and is an excellent reference.
### Pre Reqs
- Consul Enterprise License `./files/consul.lic`
- Setup shell with AWS credentials 
- Setup shell with HCP credentials if using HCP
- Terraform 1.3.7+
- aws cli
- kubectl
- helm

### Provision Infrastructure
Use terraform to build AWS Infrastructure
```
cd quickstart/1eks-selfmanaged-pg
terraform init
terraform apply -auto-approve
```

Connect to EKS using `scripts/kubectl_connect_eks.sh`.  Pass this script the path to the terraform state file used to provision the EKS cluster.  If cwd is ./1eks-selfmanaged-pg like above then this command would look like the following:
```
source ../../scripts/kubectl_connect_eks.sh .
```
This script connects EKS and builds some useful aliases shown in the output.

## Install Consul
```
cd consul_helm_values
terraform init
terraform apply -auto-approve
```

### Update Anonymous policy
Add agent read access to anonymous policy.  This allows Prometheus access to the /agent/metrics endpoint.  The following script requires access to the EKS cluster running consul.  This will setup your local shell env to use Consul CLI and update tne anonymous policy with agent "read".
```
../scripts/setEKS-ConsulEnv-AnonPolicy.sh
```
## Setup Monitoring Stack
Verify you are connected to your EKS cluster and then run the following commands to install the Metrics Stack (prometheus, grafana, fortio).
```
../../metrics/deploy_helm.sh
```
For more information read METRICS.md

## Architecture Models - Overview

### Arch 1: quickstart/consul-1eks
Creates a basic AWS VPC and managed EKS cluster with one node group.
* Deploy the AWS Load Balancer Controller
* Deploy Consul server with helm
* Deploy Observability stack (Prometheus/Grafana) with dashboards
* Deploy services into the service mesh
### Arch 2: quickstart/consul-1eks-selfmanaged-pg
Creates an AWS EKS cluster with 3 Self Managed Node Groups that will targetted with NodeSelectors to isolate workloads.
- nodegroup=default:  Observability stack
- nodegroup=consul:   Consul resources are placed here
- nodegroup=services: Any mesh or non-mesh k8s services

2 of the node groups (consul, services) are using [AWS Placement Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html) with a `cluster` strategy for higher throughput performance.

This build also deploys AWS LB, Consul, Observability stack, and services to test the service mesh.

### Arch 3: quickstart/1hcp-2vpc-2eks
Build a single datacenter service mesh with HCP Consul, and a transit gateway connecting multiple VPCs hosting different EKS clusters that need to securely discovery and route requests.

### Arch 4: quickstart/2hcp-2eks-2ec2
Deploys a Multi-Region (us-west-2, us-east-1) HCP Consul Cluster design.  Each region includes Multiple VPCs connected with a Transit gateway.   One VPC has an EKS cluster, and one hosts EC2.  The Transit gateways in each region are peered together connecting the two HCP Consul clusters to enable DR and Failover across regions.  This design only requires the management of the dataplane.  Hashicorp hosts the control plane.

### Arch 5: quickstart/2hcp-2eks-2ec2-hvnpeering
Deploys a Multi-Region (us-west-2, us-east-1) HCP Consul Cluster design that peers the Consul servers using the HVN and Terraform instead of mesh gateways in the default admin partition.
