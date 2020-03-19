#!/bin/bash -ax

PVC="$1"
NS="${2:-default}"

# verify parameters 
[ -z "$PVC" ] && echo "Must provide a PVC name." && exit 1

! kubectl get ns "$NS" && echo "Namespace $NS does not exist." && exit 1
! kubectl get -n "$NS" pvc "$PVC" && echo "PVC $PVC under $NS does not exist." && exit 1

# get pv name
PVC_UID="$( kubectl get -n "$NS" pvc "$PVC" -o jsonpath='{.metadata.uid}' )"
PV="pvc-${PVC_UID}"

# delete objects
kubectl delete -n "$NS" pvc "$PVC"

kubectl delete pv "$PV"

kubectl delete -n volume-nfs sts "$PV"

kubectl delete -n volume-nfs svc "$PV"

kubectl delete -n volume-nfs pvc "data-${PV}-0"