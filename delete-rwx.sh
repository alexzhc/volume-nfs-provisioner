#!/bin/bash -ax

nfs_pvc="$1"
nfs_ns="${2:-default}"

# verify parameters 
[ -z "$nfs_pvc" ] && echo "Must provide a nfs_pvc name." && exit 1

! kubectl get ns "$nfs_ns" && echo "Namespace $nfs_ns does not exist." && exit 1
! kubectl get -n "$nfs_ns" pvc "$nfs_pvc" && echo "nfs_pvc $nfs_pvc under $nfs_ns does not exist." && exit 1

# get pv name
nfs_pvc_uid="$( kubectl get -n "$nfs_ns" pvc "$nfs_pvc" -o jsonpath='{.metadata.uid}' )"
nfs_pv="pvc-${nfs_pvc_uid}"
nfs_sts="$nfs_pv"
data_pvc="data-${nfs_pvc_uid}"

# delete objects
kubectl delete deploy nginx && sleep 3

kubectl delete -n "$nfs_ns" pvc "$nfs_pvc"

kubectl delete pv "$nfs_pv"

kubectl delete -n volume-nfs sts "$nfs_sts"

kubectl delete -n volume-nfs svc "$nfs_sts"

kubectl delete -n volume-nfs pvc "$data_pvc"