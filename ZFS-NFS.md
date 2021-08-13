# ZFS, NFS and Kubernetes

## ZFS

Enable few features (when e.g. creating a ZFS pool) in order to do some performance increase:

```
zpool create \
    -o ashift=12 -o autotrim=on \
    -O acltype=posixacl -O compression=zstd-fast \
    -O dnodesize=auto -O normalization=formD -O relatime=on \
    -O xattr=sa [...] \
    rpool ${DISK}
```

On older systems, enable ZFS services:

```
sudo systemctl enable zfs-import-cache
sudo systemctl enable zfs-import-scan
sudo systemctl enable zfs-import.target
sudo systemctl enable zfs-mount
sudo systemctl enable zfs-share
sudo systemctl enable zfs-zed
sudo systemctl enable zfs.target
```

On newer systems:

```
sudo systemctl enable zfs.target zfs-import.service zfs-mount.service
```

Enable NFS share on your ZFS filesystem:

```
zfs set sharenfs="rw=192.168.100.204,rw=rpi4.local" zfs/db
```

Check if the share has been exported:

```
fuszenecker@rpi4:/media/zfsd/db $ showmount -e
Export list for rpi4.local:
/media/zfs/db 192.168.100.204
```

Create Persistent volume (pv):

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  storageClassName: nfs
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteMany
  nfs:
    server: rpi4.local
    path: "/media/zfs/db"
```

Create Persistent Volume Claim (pvc):

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs
  resources:
    requests:
      storage: 100Mi
```

Check if they are bound:

```
fuszenecker@rpi4:~/db $ kubectl get pv,pvc -o wide -A
NAME                          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                          STORAGECLASS    REASON   AGE   VOLUMEMODE
persistentvolume/nfs          100Mi      RWX            Retain           Bound    db/nfs                         nfs                      28m   Filesystem

NAMESPACE   NAME                                         STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS    AGE   VOLUMEMODE
db          persistentvolumeclaim/nfs                    Bound    nfs          100Mi      RWX            nfs             31m   Filesystem
```

Create test pod:

```
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  volumes:
    - name: nfs
      persistentVolumeClaim:
        claimName: nfs
  containers:
    - name: busybox
      image: busybox
      command: ['sleep', '3600']
      volumeMounts:
        - mountPath: "/nfs"
          name: nfs
```

Attach to the pod after it has been created:

```
kubectl exec -it  busybox -n db sh
```

Check if mounts work:

```
fuszenecker@rpi4:~/db $ kubectl exec -it  busybox -n db -- sh
/ # mount
[...]
rpi4.local:/media/zfs/db on /nfs type nfs4 (rw,relatime,vers=4.2,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.100.204,local_lock=none,addr=192.168.100.204)
[...]
```
