#!/bin/bash
kubectl config use-context arn:aws:eks:us-west-2:711129375688:cluster/presto-aws-team1-eks

HOST=$(kubectl -n consul get svc team1-ingress-gateway -o json | jq -r '.status.loadBalancer.ingress | select( . != null) | .[].hostname')
echo "Testing URL: http://${HOST}:8080"
echo 
while true
do
  echo "$(date):$(curl -s \
    --request GET \
   http://${HOST}:8080 \
   | jq -r '.upstream_calls' | grep name)"

  sleep 1
done
