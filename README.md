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

Please visit [RKE2 Quick Start page](https://docs.rke2.io/install/quickstart/) or [K3s page](https://k3s.io/).

Save `kubectl` config:

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
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
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

## Persistence with dynamic provisioning

### Install Longhorn

You might want to start `iscsid.service`:

```
sudo systemd enable iscsid.service
sudo systemd start iscsid.service
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

Test persistent volume claim:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-volv-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
```

### Install NFS provisioner (dynamic provisioning)

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

Later on, you can use the storage class `nfs-client` for dynamic provisioning:

### Check if persistence work

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
  storageClassName: longhorn
  # storageClassName: nfs-client
  # storageClassName: local-path
  resources:
    requests:
      storage: 1Gi

```

Use `kubectl to see bindings:

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

Example from [kubernetes-tutorials](https://github.com/imesh/kubernetes-tutorials/tree/master/create-persistent-volume.

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
