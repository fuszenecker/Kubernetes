# Logging and metrics with Grafana, Prometheus, Loki and Promtail

Create folder for storages:

```
sudo mkdir -p /var/lib/{grafana,loki,prometheus}
```

Create namespace for logging:

```
kubectl create namespace observability
```

Add helm repos:

```
helm repo add grafana https://grafana.github.io/helm-charts
## helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Create persistent volumes (`observability-storage.yaml`:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: loki
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /var/lib/loki
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - raspberry

---

apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus
spec:
  capacity:
    storage: 8Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /var/lib/prometheus
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - raspberry

---

apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /var/lib/grafana
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - raspberry
```

```
kubectl apply -f observability-storage.yaml
```

Install Grafana:

```
helm install grafana grafana/grafana -n observability --set persistence.enabled=true --set persistence.storageClassName=local-storage --set persistence.size="5Gi"
kubectl get pods,pvc,pv -n logging -o wide
```

Get the `admin` password for Grafana:

```
kubectl get secret --namespace logging grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Install Loki and Promtail, and wait until they start:

```
helm install loki-stack grafana/loki-stack -n observability --set loki.persistence.enabled=true --set loki.persistence.storageClassName=local-storage
kubectl get pods,pvc,pv -n logging -o wide
```

Install Prometheus and wait until it starts:

```
helm install prometheus prometheus-community/prometheus -n observability --set alertmanager.enabled=false --set nodeExporter.enabled=false --set pushgateway.enabled=true --set server.persistentVolume.enabled=true --set server.persistentVolume.storageClass=local-storage
kubectl get pods,pvc,pv -n logging -o wide
```

Install Tempo

```
helm install tempo grafana/tempo -n observability
```


Install Prometheus and wait until it starts:

Check everything:

```
$ kubectl get pods,pvc,pv,svc -n logging -o wide
NAME                                                READY   STATUS    RESTARTS   AGE   IP          NODE         NOMINATED NODE   READINESS GATES
pod/grafana-84b6556fd-dp7dz                         1/1     Running   0          3m    10.1.0.45   rpi4.local   <none>           <none>
pod/loki-stack-0                                    1/1     Running   0          24m   10.1.0.40   rpi4.local   <none>           <none>
pod/loki-stack-promtail-hkbs6                       1/1     Running   0          19m   10.1.0.41   rpi4.local   <none>           <none>
pod/prometheus-kube-state-metrics-bc6c8c864-nx6g8   1/1     Running   0          10m   10.1.0.43   rpi4.local   <none>           <none>
pod/prometheus-pushgateway-7767cf544-jxdxd          1/1     Running   0          10m   10.1.0.42   rpi4.local   <none>           <none>
pod/prometheus-server-7bfcf6548f-lc8lq              2/2     Running   0          10m   10.1.0.44   rpi4.local   <none>           <none>

NAME                                         STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS    AGE    VOLUMEMODE
persistentvolumeclaim/grafana                Bound    grafana      5Gi        RWO            local-storage   3m1s   Filesystem
persistentvolumeclaim/prometheus-server      Bound    prometheus   8Gi        RWO            local-storage   10m    Filesystem
persistentvolumeclaim/storage-loki-stack-0   Bound    loki         10Gi       RWO            local-storage   24m    Filesystem

NAME                          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                          STORAGECLASS    REASON   AGE     VOLUMEMODE
persistentvolume/grafana      5Gi        RWO            Delete           Bound    logging/grafana                local-storage            21s     Filesystem
persistentvolume/loki         10Gi       RWO            Delete           Bound    logging/storage-loki-stack-0   local-storage            35m     Filesystem
persistentvolume/prometheus   8Gi        RWO            Delete           Bound    logging/prometheus-server      local-storage            7m58s   Filesystem

NAME                                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE   SELECTOR
service/grafana                         ClusterIP   10.2.118.203   <none>        80/TCP     3m    app.kubernetes.io/instance=grafana,app.kubernetes.io/name=grafana
service/loki-stack                      ClusterIP   10.2.61.83     <none>        3100/TCP   24m   app=loki,release=loki-stack
service/loki-stack-headless             ClusterIP   None           <none>        3100/TCP   24m   app=loki,release=loki-stack
service/prometheus-kube-state-metrics   ClusterIP   10.2.90.101    <none>        8080/TCP   10m   app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=kube-state-metrics
service/prometheus-pushgateway          ClusterIP   10.2.87.136    <none>        9091/TCP   10m   app=prometheus,component=pushgateway,release=prometheus
service/prometheus-server               ClusterIP   10.2.215.131   <none>        80/TCP     10m   app=prometheus,component=server,release=prometheus
```

Install OpenTelemetry Collector:

```
```

Add port-forward so that you can access Grafana and Loki:

```
kubectl port-forward service/grafana 3000:80 -n observability --address=0.0.0.0
kubectl port-forward service/prometheus-server 9090:80 -n observability --address=0.0.0.0
kubectl port-forward service/loki-stack 3100 -n observability --address=0.0.0.0
kubectl port-forward service/prometheus-pushgateway 9091 -n observability --address=0.0.0.0
```

## Ingress rules

You will need a TLS-enabled ingress like this:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: logging
  annotations:
    cert-manager.io/issuer: "letsencrypt-prod"
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
      - fuszenecker-grafana.ignorelist.com
    secretName: grafana-tls
  defaultBackend:
    service:
      name: test
      port:
        number: 80
  rules:
  - host: fuszenecker-grafana.ignorelist.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
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

### LogQL examples:

`totalUpdated` comes from Serilog.

```
Rate of a counter: rate(http_request_total[5m])
P95 quantile of a histogram: histogram_quantile(0.95, sum(rate(dntelemetry_forecast_duration_seconds_bucket[125m])) by (le))
Extract data from metricslogs: avg_over_time({SourceContext="UpdateSessionLimit.Worker"} |~ "Updated (.+) sessions." | unwrap totalUpdated[60m])
```

### Variable example

Variable query, getting container names e.g. as `container`:

```
label_values(consumer_healthchecks_duration_bucket, container)
```

Data query:

```
histogram_quantile(0.95, sum(rate(consumer_healthchecks_duration_bucket{container="$container"}[5m])) by (le))
```

### Nota bene:

If there is no [official way](https://github.com/prometheus-net/prometheus-net#aspnet-core-exporter-middleware) to collect metrics, use the push gateway:

```
var pusher = new MetricPusher("http://192.168.100.204:9090/metrics", "my_app");
pusher.Start();

CreateHostBuilder(args).Build().Run();

// Serilog and Grafana are not the best friends.
Log.CloseAndFlush();
pusher.Stop();
```

Services need to be annotated to be scraped by Prometheus.

```
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    prometheus.io/port: telemetry
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
      name: telemetry
```
