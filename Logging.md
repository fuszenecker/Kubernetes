# Logging with Elasticsearch and Kibana

Create namespace for logging:

```
kubectl create namespace logging
```

Add helm repo:

```
helm repo add elastic https://helm.elastic.co
```

Add a test version of Elasticsearch, no storage is configured:

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
kubectl port-forward service/elasticsearch-master 9200:9200 -n logging --address=0.0.0.0
```

## Serilog setup


For Serilog, use the configuration: 

```
.WriteTo.Elasticsearch(new Serilog.Sinks.Elasticsearch.ElasticsearchSinkOptions(new Uri("http://localhost:9200")) {
    AutoRegisterTemplate = true,
    AutoRegisterTemplateVersion = AutoRegisterTemplateVersion.ESv7,
    IndexFormat = $"{Assembly.GetExecutingAssembly().GetName().Name.ToLower()}-{DateTime.UtcNow:yyyy-MM}"
})
```

rs `appsettings.json`:

```
"WriteTo": [{
    "Name": "Elasticsearch",
    "Args": {
      "nodeUris": "http://localhost:9200",
      "indexFormat": "myapplication-{0:yyyy.MM}",
      "autoRegisterTemplate": true,
      "autoRegisterTemplateVersion": "ESv7"
    }
}]
```

## Kibana setup

1. Check indices: `http://localhost:5601/app/management/data/index_management/indices`
2. Add index pattern: `http://localhost:5601/app/management/kibana/indexPatterns`
3. You can access log items in Kibana through: `http://localhost:5601/app/discover`
