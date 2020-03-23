# volume-nfs-provisioner
Dynamically provisioned NFS exports for Kubernetes block volumes

## Overview
This project aims to provide "per-volume" nfs export for block volumes . It uses NFS kernel server for performance and K8S ClusterIP for HA.

## Roadmap
1. static pvc creation by a script

1. dynamic pvc creation by kubernetes-incubator/external-storage

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

After exection, basides the RWX PVC/PV, you will see a statefulset named after the PV is created in `volume-nfs` namespace. The statefulset mounts another RWO PVC/PV which is a block volume created with storageclass `block-storage-sc`.

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
```

NFS SVC:
```
$ kubectl -n volume-nfs describe svc pvc-8c61818e-0936-4833-b5dc-29cfa253d675
...
Type:              ClusterIP
IP:                10.96.3.111
Port:              nfs  2049/TCP
TargetPort:        2049/TCP
Endpoints:         192.168.176.168:2049
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


