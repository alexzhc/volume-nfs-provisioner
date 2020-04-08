#!/bin/bash -ax

nfs_pvc="$1"
data_sc="$2"
size="${3:-'1Gi'}"
nfs_ns="${4:-default}"

# verify arguments 
[ -z "$nfs_pvc" ] && echo "Must provide a PVC name." && exit 1
[ -z "$data_sc" ] && echo "Must provide an SC name." && exit 1

! kubectl get ns "$nfs_ns" && echo "Namespace $nfs_ns does not exist." && exit 1
kubectl get -n "$nfs_ns" pvc "$nfs_pvc" && echo "PVC $nfs_pvc under $nfs_ns exists." && exit 1
! kubectl get sc "$data_sc" && echo "SC $data_sc dose not exist." && exit 1

# create nfs pvc
envsubst < tmpl/nfs-pvc.yaml | kubectl apply -f -
nfs_pvc_uid="$( kubectl get -n "$nfs_ns" pvc "$nfs_pvc" -o jsonpath='{.metadata.uid}' )"
nfs_pv="pvc-${nfs_pvc_uid}"

# create data pvc
data_pvc="data-${nfs_pvc_uid}"
envsubst < tmpl/data-pvc.yaml | kubectl apply -f -
data_pvc_uid="$( kubectl get -n volume-nfs pvc "$data_pvc" -o jsonpath='{.metadata.uid}' )"
data_pv="pvc-${data_pvc_uid}"

# create nfs statefulset
nfs_sts="$nfs_pv"
envsubst < tmpl/nfs-sts.yaml | kubectl apply -f -

# get service cluserip
SECONDS=0
cluster_ip=
while [ -z "$cluster_ip" ] ; do
    cluster_ip="$( kubectl -n volume-nfs get svc "$nfs_sts" -o jsonpath='{.spec.clusterIP}' )"
    sleep 2
    [ "$SECONDS" -ge 30 ] && echo 'Cannot get cluster ip, failed to create nfs pvc' && exit 1
done 

# create pv
envsubst < tmpl/nfs-pv.yaml | kubectl apply -f -

# wait for service endpoints to be ready
SECONDS=0
endpoints=
while [ -z "$endpoints" ] ; do
    endpoints="$( kubectl -n volume-nfs get ep "$nfs_sts" -o jsonpath='{.subsets[0].addresses[0].ip}' )"
    sleep 2
    [ "$SECONDS" -ge 300 ] && echo 'Cannot get endpoints, please check volume-nfs pod' && exit 1
done 

echo "nfs_pvc ${nfs_pvc} is Ready!"

kubectl -n "$nfs_ns" get pvc "$nfs_pvc"