# Kubernetes setup

## Cluster setup

```
sudo kubeadm init --apiserver-advertise-address 192.168.100.204 --pod-network-cidr 10.1.0.0/16 --service-cidr 10.2.0.0/16 # --control-plane-endpoint=fuszenecker.ignorelist.com --apiserver-advertise-address=192.168.100.204
kubectl taint nodes --all node-role.kubernetes.io/master-
```

`--control-plane-endpoint` and `--apiserver-advertise-address` are for HA clusters.

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

helm install ingress ingress-nginx/ingress-nginx -n kube-system --set controller.hostNetwork=true
```

Check if Nginx listens on node port (host network):

```
netstat -nlt | egrep '(:80)|(:443)'
netstat -nlt
```

You should see that something is listening on :80 and :443

## Install Certificate manager ([cert-manager.io](https://cert-manager.io/docs/installation/)) for managing TLS certificates issued by e.g. Let's Encrypt

```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
```

Forther steps: [Certificate Manager + Let's Encrypt](https://cert-manager.io/docs/tutorials/acme/ingress/#step-6-configure-let-s-encrypt-issuer)

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
kubectl port-forward svc/kibana-kibana 3000:3000 --address 0.0.0.0 -n elk
```

Say goodbye to a custer:

```
sudo kubeadm reset
```

## Helm useful commands

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search hub | grep rabbit
helm install mychart myrepo/mychart -n mynamespace
helm list -A
helm repo index .
```
