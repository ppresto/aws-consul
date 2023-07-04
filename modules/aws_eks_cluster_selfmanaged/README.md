# Self Managed Node Groups Example

Configuration in this directory creates an AWS EKS cluster with 3 Self Managed Node Groups.

## EKS Node Groups
- default:  Anything can be put here like a monitoring stack.
- consul:   Consul resources should be placed here
- services: All service mesh enabled services

## AWS Placement Groups
2 of these node groups (consul, services) are using [AWS Placement Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html) with a `cluster` strategy for higher throughput performance.

## AWS - EKS Load Balancer Controller
The AWS Load Balancer Controller has been installed to enable internal NLB routing for Mesh Gateways.

