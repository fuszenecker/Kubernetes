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

Install Kibana and wait until it starts:

```
helm install kibana elastic/kibana -n logging 
kubectl get pods -n logging
```

Check services:

```
kubectl get pods -n logging
```

Add port-forward so that you can access Kibana:

```
kubectl port-forward service/kibana-kibana 5601:5601 -n logging --address=0.0.0.0
```

You can access Kibana trrough: `http://127.0.0.1:5601/`
