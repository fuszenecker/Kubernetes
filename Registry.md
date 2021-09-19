# Registry

## Create filesystem for registry

```
zfs create externale/registry
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

