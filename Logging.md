# Logging

```
kubectl create namespace logging
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch -n logging --set replicas=1 --set persistence=false
kubectl get pods -n logging

```
