# Logging

Create namespace for logging:

```
kubectl create namespace logging
```

Add helm repo:

```
helm repo add elastic https://helm.elastic.co
```

Add a test version of elasticsearch, no storage is configured:

```
helm install elasticsearch elastic/elasticsearch -n logging --set replicas=1 --set persistence.ebalbes=false
```

Wait until the pod starts:

```
kubectl get pods -n logging
```

Install Kibana:

```
helm install kibana elastic/kibana -n logging 
```
