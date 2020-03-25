# volume-nfs-provisioner
Dynamically provisioned NFS exports for Kubernetes block volumes

## Overview
This project aims to provide "per-volume" nfs export for block volumes .

It uses NFS kernel server for performance and K8S ClusterIP for HA.

NFS failover is handled by a Kubernetes Pod. 

## Diagrams
Data Plane:
```
+-------+       +-------+        +-------+
| nginx |       | nginx |        | nginx |
|  pod1 |       |  pod2 |        |  pod3 |
+---+---+       +---+---+        +---+---+
    ^               ^                ^
    |               |                |
    |          +----+-----+          |
    +----------+  NFS PVC +----------+
               +----^-----+
                    |
                +---+----+
                | NFS PV |
                +---^----+
                    |
             +------+-------+
             | (cluster ip) |
             |              |
             | NFS POD/HOST |
             +------^-------+
                    |
               +----+-----+
               | DATA PVC |
               +----^-----+
                    |
               +----+----+
               | DATA PV |
               +---------+
```

Control Plane (dynamic provisioning):
```
                                              +--------+
                         +---------------+    | Block  |
                    +--->+ ReadWriteOnce +--->+ Volume +-------------------------------+
                    |    +---------------+    +--------+                               |
                    |                                                                  |
                    |                                                                  v
+-----+    +--------+                                                                +-+--+
| PVC +--->+ Access |                                                                | PV |
+-----+    |  Mode? |                                                                +-+--+
           +--------+                                                                  ^
                    |                                                                  |
                    |                         +--------+    +--------+    +--------+   |
                    |    +---------------+    | Block  |    | NFS    |    | NFS    |   |
                    +--->+ ReadWriteMany +--->+ Volume +--->+ Export +--->+ Volume +---+
                         +---------------+    +--------+    +--------+    +--------+
```

## Roadmap
Step 1. define workflow of a static pvc creation. [Done]

Step 2. dynamic pvc creation by "nested storageclass", e.g.
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: volume-nfs-sc
provisioner: nfs.volume.io
reclaimPolicy: Delete
parameters:
  backendStorageClass: block-storage-sc
```
Step 3. dynamic pvc creation by "nested provisioner", e.g
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: volume-nfs-sc
provisioner: nfs.volume.io
reclaimPolicy: Delete
parameters:
  backendProvisioner: block.storage.io
  backendParameter1:
  backendParameter2:
```
Step 4. aggregate cli to `kubectl`, e.g.
```
$ kubectl get persistentVolumeExport
NAME                                      EXPORT                                      STORAGECLASS    VIP          NODE           CLAIM
pvc-8c61818e-0936-4833-b5dc-29cfa253d675  /pvc-50123022-e0ec-4f58-9b7c-fce105d73e91   volume-nfs-sc   10.96.2.218  k8s-worker-1   default/rwx-pvc
```
## Compatibility
Any block storage system that has implemented k8s dynamic provisioning

## Pre-requisite
nfs-kernel-server be installed on each k8s node
```
# rhel/centos
yum install -y nfs-server

# debian/ubuntu
apt-get install nfs-kernel-server
```

## Guide
Assume you want create in `default` namespace a `10GiB` sized RWX PVC named `rwx-pvc` from StorageClass named `block-storage-sc`.

```
./create-rwx.sh rwx-pvc block-storage-sc rwx-pvc 10Gi
```

To delete 
```
./delete-rwx.sh rwx-pvc
```

## A closer look
After creation, basides the RWX PVC/PV, you will see a statefulset named after the PV is created in `volume-nfs` namespace. The statefulset mounts another RWO PVC/PV which is a block volume created with storageclass `block-storage-sc`.

RWX PVC:
```
$ kubectl -n default get pvc rwx-pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
rwx-pvc   Bound    pvc-8c61818e-0936-4833-b5dc-29cfa253d675   10Gi       RWX                           26s
```

RWX PV:
```
$ kubectl -n default get pv pvc-8c61818e-0936-4833-b5dc-29cfa253d675
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   REASON   AGE
pvc-8c61818e-0936-4833-b5dc-29cfa253d675   10Gi       RWX            Delete           Bound    default/rwx-pvc                           6m44s

$ kubectl describe pv pvc-8c61818e-0936-4833-b5dc-29cfa253d675
...
Source:
    Type:      NFS (an NFS mount that lasts the lifetime of a pod)
    Server:    10.96.3.111
    Path:      /var/lib/volume/nfs/pvc-50123022-e0ec-4f58-9b7c-fce105d73e91
    ReadOnly:  false
...
```

NFS Statefulset:
```
$ kubectl -n volume-nfs get sts -o wide
NAME                                       READY   AGE    CONTAINERS   IMAGES
pvc-8c61818e-0936-4833-b5dc-29cfa253d675   1/1     9m1s   exporter     alexzhc/nfs-exporter

$ kubectl -n volume-nfs get po -o wide
NAME                                         READY   STATUS    RESTARTS   AGE    IP                NODE           NOMINATED NODE
pvc-8c61818e-0936-4833-b5dc-29cfa253d675-0   1/1     Running   0          9m4s   192.168.176.161   k8s-worker-1
```

NFS SVC:
```
$ kubectl -n volume-nfs describe svc pvc-8c61818e-0936-4833-b5dc-29cfa253d675
...
Type:              ClusterIP
IP:                10.96.3.111
Port:              nfs  2049/TCP
TargetPort:        2049/TCP
Endpoints:         192.168.176.161:2049
...
```

Data PVC:
```
$ kubectl -n volume-nfs get pvc
NAME                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS            AGE
data-8c61818e-0936-4833-b5dc-29cfa253d675   Bound    pvc-50123022-e0ec-4f58-9b7c-fce105d73e91   10Gi       RWX            block-storage-sc        10m
```

Data PV:
```
$ kubectl -n volume-nfs get pv pvc-50123022-e0ec-4f58-9b7c-fce105d73e91
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                  STORAGECLASS            REASON   AGE
pvc-50123022-e0ec-4f58-9b7c-fce105d73e91   10Gi       RWX            Delete           Bound    volume-nfs/data-8c61818e-0936-4833-b5dc-29cfa253d675   block-storage-sc                 11m
```

On node `k8s-worker-1`:
```
$ cat /etc/exports
/var/lib/volume/nfs/pvc-50123022-e0ec-4f58-9b7c-fce105d73e91 192.168.176.161/16(rw,insecure,no_root_squash,no_subtree_check,crossmnt)

$ df -hT /var/lib/volume/nfs/pvc-50123022-e0ec-4f58-9b7c-fce105d73e91
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/drbd1000  ext4  9.8G   37M  9.3G   1% /var/lib/volume/nfs/pvc-50123022-e0ec-4f58-9b7c-fce105d73e91
```

On any node with `kube-proxy`:
```
$ showmount -e 10.96.3.111
Export list for 10.96.2.210:
/var/lib/volume/nfs/pvc-50123022-e0ec-4f58-9b7c-fce105d73e91 192.168.176.161/16
```

