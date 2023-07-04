# Single EKS cluster with Placement Groups and self managed EKS node groups.
This configuration creates an AWS EKS cluster using placement groups and 3 Self Managed Node Groups. This is designed for performance and can be deployed with a monitoring stack for load testing.
- default:  monitoring stack (prometheus/grafana)
- consul:   Consul cluster
- services: service mesh enabled services

### AWS Placement Groups
2 of these node groups (consul, services) are using [AWS Placement Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html) with a `cluster` strategy for higher throughput performance.

### AWS - EKS Load Balancer Controller
The AWS Load Balancer Controller can be enabled for NLB routing to support Mesh Gateways or any EKS Load balancer requirements (ex: expose consul servers, ui, or monitoring stack).

## Getting Started

### Pre Reqs
- Consul Enterprise License copied to `./files/consul.lic`
- Setup shell with AWS credentials (need permission to build all networking, ec2, eks, & placement groups)
- Terraform 1.3.7+
- aws cli
- kubectl
- Consul 1.14.6+  (optional)

### Provision Infrastructure
Use terraform to build infra
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
After installing consul the helm.values used will be written to ./consul_helm_values/helm/.  This file can be used with helm for troubleshooting, upgrades, etc...

### Update Anonymous policy to support metrics
Add agent read access to anonymous policy.  This allows Prometheus access to the /agent/metrics endpoint.  The following script requires auth to the EKS cluster running consul and that Consul be installed locally for the CLI.  This will connect to the EKS cluster running consul to setup your local shell env to use Consul CLI and update tne anonymous policy with agent "read".
```
../../scripts/setEKS-ConsulEnv-AnonPolicy.sh
```

## Setup Monitoring Stack
Metrics gathering is currently being configured outside of this repo. Verify you are connected to your EKS cluster and then run the following commands to clone the Metrics Stack (prometheus, grafana, fortio) repo.
```
cd ../../../metrics
```

Setup the Stack (Prometheus, Grafana)
```
./deploy_helm.sh
```
### Fortio loadtests
There are multiple test cases contained within a directory.
* fortio-baseline
* fortio-consul

Deploy fortio test cases
```
./fortio-tests/deploy.sh
```

Undeploy the test use case by providing any value as a parameter (ex: delete)
```
./fortio-tests/deploy.sh delete
```



