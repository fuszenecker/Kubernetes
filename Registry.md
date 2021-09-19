# Registry

## Create filesystem for registry

```
sudo zfs create -o mountpoint=/media/externale/registry externale/registry
sudo adduser registry
sudo chown -R registry:registry /media/externale/registry
```

## Create persistent volume

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: registry
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /media/externale/registry
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - rpi4.local
```

## Setup the LetsEncrypt issues in this namespace:

`kubectl create namespace registry`

```
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-prod
  namespace: registry
spec:
  acme:
    email: robert.fuszenecker@outlook.com
    preferredChain: ""
    privateKeySecretRef:
      name: letsencrypt-prod
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - http01:
        ingress:
          class: nginx
```

## Install the registry

Create `values.yaml`:

```
replicaCount: 1

updateStrategy: {}

podAnnotations: {}
podLabels: {}

image:
  repository: registry
  tag: 2.7.1
  pullPolicy: IfNotPresent

service:
  name: registry
  type: ClusterIP
  port: 5000
  annotations: {}

ingress:
  enabled: false
  path: /
  hosts:
    - fuszenecker-registry.ignorelist.com
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    cert-manager.io/issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  labels: {}
  tls:
    # Secrets must be manually created in the namespace.
    - secretName: registry-tls
      hosts:
        - fuszenecker-registry.ignorelist.com

resources: {}

persistence:
  accessMode: 'ReadWriteOnce'
  enabled: true
  size: 10Gi
  storageClass: 'local-storage'

# set the type of filesystem to use: filesystem, s3
storage: filesystem

# Set this to name of secret for tls certs
# tlsSecretName: registry.docker.example.com
secrets:
  haSharedSecret: ""
  htpasswd: ""

# https://docs.docker.com/registry/recipes/mirror/
proxy:
  enabled: false
  remoteurl: https://registry-1.docker.io
  username: ""
  password: ""
  secretRef: ""

configData:
  version: 0.1
  log:
    fields:
      service: registry
  storage:
    cache:
      blobdescriptor: inmemory
  http:
    addr: :5000
    headers:
      X-Content-Type-Options: [nosniff]
  health:
    storagedriver:
      enabled: true
      interval: 10s
      threshold: 3

securityContext:
  enabled: true
  runAsUser: 1100
  fsGroup: 1100

priorityClassName: ""
podDisruptionBudget: {}
nodeSelector: {}
affinity: {}
tolerations: []
extraVolumeMounts: []
extraVolumes: []
```

```
helm repo add twuni https://helm.twun.io
helm repo update

helm install twuni/docker-registry -n registry -f values.yaml
```

Create the ingress manually (the chart is a bit old):

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  name: registry
  namespace: registry
spec:
  rules:
  - host: fuszenecker-registry.ignorelist.com
    http:
      paths:
      - backend:
          service:
            name: registry-docker-registry
            port:
              number: 5000
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - fuszenecker-registry.ignorelist.com
    secretName: registry-tls
```

The annotation `nginx.ingress.kubernetes.io/proxy-body-size: "0"` prevents status response `413` on uploads. 
