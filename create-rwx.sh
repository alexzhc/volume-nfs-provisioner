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

# create nfs_pvc
cat nfs-pvc.yaml | envsubst '${nfs_pvc} ${size} ${nfs_ns}' | kubectl apply -f -
nfs_pvc_uid="$( kubectl get -n "$nfs_ns" pvc "$nfs_pvc" -o jsonpath='{.metadata.uid}' )"
nfs_pv="pvc-${nfs_pvc_uid}"


# deploy nfs export
cat nfs-pod.yaml | envsubst '${nfs_pv} ${nfs_pvc} ${nfs_ns} ${data_sc} ${size}' | kubectl apply -f -

exit 0

# get service cluserip
SECONDS=0
cluster_ip=
while [ -z "$cluster_ip" ] ; do
    cluster_ip="$( kubectl -n volume-nfs get svc "$nfs_pv" -o jsonpath='{.spec.clusterIP}' )"
    sleep 1
    [ "$SECONDS" -ge 30 ] && echo 'Cannot get cluster ip, failed to create nfs pvc' && exit 1
done 

# get data pv name
data_pvc="data-${nfs_pod_uid}-0"
data_pvc_uid="$( kubectl get -n volume-nfs pvc "$data_pvc" -o jsonpath='{.metadata.uid}' )"
data_pv="nfs_pvc-${data_pvc_uid}"

# wait for service to be ready
SECONDS=0
endpoints=
while [ -z "$endpoints" ] ; do
    endpoints="$( kubectl -n volume-nfs get ep "$nfs_pv" -o jsonpath='{.subsets[0].addresses[0].ip}' )"
    sleep 1
    [ "$SECONDS" -ge 300 ] && echo 'Cannot get endpoints, please check volume-nfs pod' && exit 1
done 


# create pv
cat pv.yaml | envsubst '${nfs_pvc} ${nfs_pv} ${size} ${nfs_ns} ${data_pv} ${cluster_ip}' | kubectl apply -f -

echo "nfs_pvc ${nfs_pvc} is Ready!"

kubectl -n "$nfs_ns" get nfs_pvc "$nfs_pvc"
