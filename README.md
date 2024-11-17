# Kubernetes setup

## Bash setup

You will need some tools to be installed beforehand:

* kubectl
* helm
* nmap (optional)
* open-iscsi for Longhorn (optional)

Optionally, you can setup the `bash` completion:

```
sudo -i
kubectl completion bash >/etc/bash_completion.d/kubectl
```

## Cluster setup

Please visit the [RKE2 Quick Start page](https://docs.rke2.io/install/quickstart/) or the [K3s homepage](https://k3s.io/).

Add permission to configuration file (K3s):

```
setfacl -m u:fuszenecker:r /etc/rancher/k3s/k3s.yaml
ln -s /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

Or save `kubectl` config (RKE2):

```
mkdir -f ~/.kube
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
```

Check if pods are ready and running:

```
kubectl get pods -A
kubectl get pods -Aw
```

To check if the HTTP and HTTPS ports are open:

```
nmap -n localhost
[...]
80/tcp    open  http
[...]
443/tcp   open  https
[...]
```

## Install Certificate manager ([cert-manager.io](https://cert-manager.io)) for managing TLS certificates

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

Install cluster issuer (you can deploy per-namespace issuers, as well):

```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: robert.fuszenecker@outlook.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - http01:
        ingress:
          class: nginx
          # For K3s:
          # class: traefik
```

Test TLS certificate with an [ingress resource](https://kubernetes.io/docs/concepts/services-networking/ingress/): see the next subsections.

### Ingress example for NGINX controller

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myingress
  namespace: mynamespace
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
      - fuszenecker.eu
    secretName: letsencrypt-prod-cert
  rules:
  - http:
      paths:
      - path: /mypath(/|$)(.*)
        backend:
          service:
            name: myservice
            port:
              number: 8000
```

### Ingress example for Traefik controller

```
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: strip-prefix
  namespace: mynamespace
spec:
  stripPrefix:
    prefixes:
      - "/mypath"
    forceSlash: true

---

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myingress
  namespace: mynamespace
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: mynamespace-strip-prefix@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
      - fuszenecker.eu
    secretName: letsencrypt-prod-cert
  rules:
  - http:
      paths:
      - path: /mypath
        pathType: Prefix
        backend:
          service:
            name: myservice
            port:
              number: 8000
```

### Check certificate requests and certificates

```
kubectl describe certificaterequests -A
kubectl describe certificates -A
```

### IPv6 proxying

Create the service definition `/etc/systemd/system/socat.service`:

```
[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/bin/socat TCP6-LISTEN:443,fork,reuseaddr TCP4:127.0.0.1:443
Restart=always
RestartSec=10
```

Enable and start service:

```
systemd enable socat
systemd start socat
systemd status socat
```

## Observability

```
kubectl create namespace observability
```

### Logs

```
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo
```

```
helm install opensearch opensearch/opensearch -n observability --set singleNode=true --set persistence.enabled=true --set persistence.storageClass=local-storage --set persistence.size=8Gi
```

Create PV for `opensearch`:

```
sudo mkdir -p /var/lib/observability
```

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: observability-data
spec:
  capacity:
    storage: 8Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /var/lib/observability
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
kubectl create ns openobserve
kubectl apply -f https://raw.githubusercontent.com/zinclabs/openobserve/main/deploy/k8s/statefulset.yaml
```

Create ingress for `openobserve`:

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openobserve-ingress
  namespace: openobserve
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
      - fuszenecker.eu
      - grafana.fuszenecker.eu
    secretName: openobserve-tls
  rules:
  - host: grafana.fuszenecker.eu
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openobserve
            port:
              number: 5080
```

## Persistence with dynamic provisioning

### Install Longhorn

You might want to start `iscsid.service`:

```
sudo systemctl enable iscsid.service
sudo systemctl start iscsid.service
```

```
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
```

You can create your own storageclass:

```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
```

Later on, you can use the storage class `longhorn` for dynamic provisioning.

### Install NFS provisioner

Ensure that `nfs-server.local.net:/srv/nfs` is exported, on `nfs-server.local.net` run:

```
sudo exportfs -v
```

If the NFS share is ready, run:

```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

kubectl create namespace nfs-subdir-external-provisioner

helm install nfs-subdir-external-provisioner \
    nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    -n nfs-subdir-external-provisioner \
    --set nfs.server=nfs-server.local.net \
    --set nfs.path=/srv/nfs
```

Later on, you can use the storage class `nfs-client` for dynamic provisioning.

### Check if persistence works

Persistence volume claim:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: busybox-pvc
  namespace: mynamespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  # storageClassName: longhorn
  # storageClassName: local-path
  resources:
    requests:
      storage: 1Gi

```

Use `kubectl` to see bindings:

```
kubectl get pvc,pv -n mynamespace
```

Pod to work with data:

```
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: mynamespace
spec:
  containers:
    - name: busybox
      image: k8s.gcr.io/busybox
      command: [ "/bin/sh", "-c", "tail -f /dev/null" ]
      volumeMounts:
      - name: myvolume
        mountPath: "/mnt/myvolume"
  volumes:
  - name: myvolume
    persistentVolumeClaim:
      claimName: busybox-pvc
  restartPolicy: Never
```

Attach to `busybox`:

```
kubectl exec -it busybox sh
echo "Hello persistent volumes!" > /mnt/myvolume/hello-pv.txt
cat /mnt/myvolume/hello-pv.txt
```

Example from [kubernetes-tutorials](https://github.com/imesh/kubernetes-tutorials/tree/master/create-persistent-volume).

## Kubernetes useful commands

[kubectl cheat sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

Get all pods

```
kubectl get pods -A -o wide
kubectl get pods -Aw  -o wide
```

Run a busybox or mini-debian:

```
kubectl run -it --rm busybox --image=busybox -n kube-system -- sh
kubectl run -it --rm debian-slim --image=debian -- bash
```

Run a shell within a running image:

```
kubectl exec --stdin --tty my-pod -- /bin/sh
```

Check the logs of a running service (all pods):

```
kubectl logs -f -n kube-system svc/my-service
```

Check ingress routes:

```
kubectl describe ingress -A
```

Port-forward (temporarily) a host port to a running service without using ingress:

```
kubectl port-forward service/grafana 3000:80 -n logging --address=0.0.0.0
```

## Helm useful commands

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search hub | grep rabbit
helm search repo ingress-nginx
helm search repo ingress-nginx -l
helm install mychart myrepo/mychart -n mynamespace
helm install mychart myrepo/mychart -n mynamespace --version 1.7.0
helm upgrade mychart -n mynamespace .
helm list -A
helm repo index .
```

### Minecraft

```
kubectl create namespace minecraft
helm repo add minecraft-server-charts https://itzg.github.io/minecraft-server-charts/
helm install minecraft-bedrock minecraft-server-charts/minecraft \
     -n minecraft \
     --set minecraftServer.eula=true \
     --set persistence.storageClass="local-path" \
     --set persistence.dataDir.enabled=true
```

## Useful links

* Rancher RKE2: https://docs.rke2.io/ and https://github.com/rancher/rke2
* Rancher K3s: https://k3s.io/ and https://github.com/k3s-io/k3s
* https://artifacthub.io/
* https://artifacthub.io/packages/helm/rancher-latest/rancher
* https://artifacthub.io/packages/helm/nfs-subdir-external-provisioner/nfs-subdir-external-provisioner
