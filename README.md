# Kubernetes setup

## Bash setup

It's better to set up autocompletion in the very beginning:

```
sudo -i
kubectl completion bash >/etc/bash_completion.d/kubectl
```

## Cluster setup

```
sudo kubeadm init --apiserver-advertise-address 192.168.100.204 --service-cidr 10.1.0.0/16 --pod-network-cidr 10.2.0.0/16 # --control-plane-endpoint fuszenecker.ignorelist.com
kubectl taint nodes --all node-role.kubernetes.io/master-
```

`--control-plane-endpoint` is for HA clusters (with multiple master plane).

## Installing pod networking

```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Check if pods are ready:

```
kubectl get pods -A
kubectl get pods -Aw
```

## Install Nginx ingress

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress ingress-nginx/ingress-nginx -n kube-system --set controller.service.type=NodePort --set controller.service.nodePorts.http=32000 --set controller.service.nodePorts.https=32001

# This is the old, a bit unsecure way: helm install ingress ingress-nginx/ingress-nginx -n kube-system --set controller.hostNetwork=true
```

Check if Nginx listens on node port (host network):

```
netstat -nlt | egrep '(:32000)|(:32001)'
netstat -nlt
```

You should see that something is listening on `:32000` and `:32001`:

```
tcp        0      0 0.0.0.0:32000           0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:32001           0.0.0.0:*               LISTEN
```

## Install Certificate manager ([cert-manager.io](https://cert-manager.io/docs/installation/)) for managing TLS certificates issued by e.g. Let's Encrypt

```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.yaml
```

Forther steps: [Certificate Manager + Let's Encrypt](https://cert-manager.io/docs/tutorials/acme/ingress/#step-6-configure-let-s-encrypt-issuer)

⚠️ You might want to install certificate issuer to each namespace that contains a service to be exposed.

```
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-prod
  namespace: ???
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

Ron a shell within a running image:

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

Say goodbye to a custer:

```
sudo kubeadm reset
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
