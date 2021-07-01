# Logging with Grafana, Loki and Promtail

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

Add a test version of Grafana, no storage is configured:

```
helm install Grafana grafana/grafana -n logging
```

Wait until the pod starts:

```
kubectl get pods -n logging
```

Get the `admin` password for Grafana:

```
kubectl get secret --namespace logging grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Install Loki and Promtail, and wait until they start:

```
helm install loki grafana/loki -n logging
helm install promtail grafana/promtail --set "loki.serviceName=loki" -n logging
kubectl get pods -n logging
```

Or maybe:

```
helm install loki-stack grafana/loki-stack -n logging --set promtail.enabled=true,loki.persistence.enabled=false
kubectl get pods -n logging
```

Install Prometheus and wait until it starts:

```
helm install prometheus prometheus-community/prometheus -n logging --set alertmanager.enabled=false --set nodeExporter.enabled=false --set pushgateway.enabled=true --set server.persistentVolume.enabled=false
kubectl get pods -n logging
```

Check services:

```
kubectl get pods -n logging
```

Add port-forward so that you can access Grafana and Loki:

```
kubectl port-forward service/grafana 8080:80 -n logging --address=0.0.0.0
kubectl port-forward service/prometheus-server 9090:80 -n logging --address=0.0.0.0
kubectl port-forward service/loki 3100 -n logging --address=0.0.0.0
kubectl port-forward service/prometheus-pushgateway 9091 -n logging --address=0.0.0.0
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

Nota bene:

```
var pusher = new MetricPusher("http://192.168.100.204:9090/metrics", "update_session_limit");
pusher.Start();

CreateHostBuilder(args, customerId, sessionLimit).Build().Run();

// Serilog and Grafana are not the best friends.
Log.CloseAndFlush();
pusher.Stop();
```
