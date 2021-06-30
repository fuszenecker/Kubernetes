# Logging with Grafana and Loki

Create namespace for logging:

```
kubectl create namespace logging
```

Add helm repos:

```
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Add a test version of Elasticsearch, no storage is configured:

```
helm install grafana grafana/grafana -n logging
```

Wait until the pod starts:

```
kubectl get pods -n logging
```

Get the `admin` password for Grafana:

```
kubectl get secret --namespace logging grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Install Loki and wait until it starts:

```
helm install loki grafana/loki -n logging 
kubectl get pods -n logging
```

Install Prometheus and wait until it starts:

```
helm install prometheus prometheus-community/prometheus -n logging --set alertmanager.enabled=false --set nodeExporter.enabled=false --set pushgateway.enabled=false --set server.persistentVolume.enabled=false
kubectl get pods -n logging
```

Check services:

```
kubectl get pods -n logging
```

Add port-forward so that you can access Grafana and Loki:

```
kubectl port-forward service/grafana 8080:80 -n logging --address=0.0.0.0
kubectl port-forward service/loki 3100 -n logging --address=0.0.0.0
kubectl port-forward service/prometheus-server 9090:80 -n logging --address=0.0.0.0
```

## Serilog setup


For Serilog, use the configuration in `appsettings.json`:

```
"WriteTo": [{
  "Name": "LokiHttp",
  "Args": {
    "serverUrl": "http://localhost:3100"
  }
}]
```

Remainder:

```
CreateHostBuilder(args).Build().Run();

// Serilog and Loki are not the best friends.
Log.CloseAndFlush();
```
