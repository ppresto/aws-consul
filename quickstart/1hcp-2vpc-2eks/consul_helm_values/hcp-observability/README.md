# Setup Observability

# Instructions in HCP
# https://portal.cloud.hashicorp.com/services/consul/clusters/hcp/presto-cluster-usw2/observability?project_id=328306de-41b8-43a7-9c38-ca8d89d06b07

export HCP_CLIENT_ID="mP7VTCkNDwwKNrAzt0q0QWDgPJX5E8Qo"
export HCP_CLIENT_SECRET="Ec5PCRBVFj_46SUrXiIbHmwrkC4SR9qmRdu9XrVeRMjcDli7V8QAahThPqvufrIF"
export HCP_RESOURCE_ID="organization/66cfdca4-69d4-468c-8ea6-e688a8c97994/project/328306de-41b8-43a7-9c38-ca8d89d06b07/hashicorp.consul.global-network-manager.cluster/presto-cluster-usw2"

kubectl create secret generic consul-hcp-client-id --from-literal=client-id=$HCP_CLIENT_ID --namespace consul
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret=$HCP_CLIENT_SECRET --namespace consul
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id=$HCP_RESOURCE_ID --namespace consul

#Update values.yaml
helm upgrade consul-web-web1 hashicorp/consul --namespace consul --values yaml/auto-consul-web-web1-values-dataplane-hcp.yaml

#create intention
cat <<EOF | kubectl apply --namespace consul --filename -
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: consul-telemetry-collector
spec:
  destination:
    name: consul-telemetry-collector
  sources:
  - action: allow
    name: '*'
EOF


