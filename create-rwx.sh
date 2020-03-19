#!/bin/bash -ax

PVC="$1"
SC="$2"
SIZE="${3:-'1Gi'}"
NS="${4:-default}"

# verify arguments 

[ -z "$PVC" ] && echo "Must provide a PVC name." && exit 1
[ -z "$SC" ] && echo "Must provide an SC name." && exit 1

! kubectl get ns "$NS" && echo "Namespace $NS does not exist." && exit 1
kubectl get -n "$NS" "$PVC" && echo "PVC $PVC under $NS exists." && exit 1
! kubectl get sc "$SC" && echo "SC $SC dose not exist." && exit 1

# create pvc
cat pvc.yaml | envsubst '${PVC} ${SIZE} ${NS}' | kubectl apply -f -
PVC_UID="$( kubectl get -n "$NS" pvc "$PVC" -o jsonpath='{.metadata.uid}' )"
PV="pvc-${PVC_UID}"

# deploy nfs export
cat volume-nfs.yaml | envsubst '${PV} ${PVC} ${NS} ${SC} ${SIZE}' | kubectl apply -f -

# get service cluserip
SECONDS=0
CLUSTER_IP=
while [ -z "${CLUSTER_IP}" ] ; do
    CLUSTER_IP="$( kubectl -n volume-nfs get svc "$PV" -o jsonpath='{.spec.clusterIP}' )"
    sleep 1
    [ "${SECONDS}" -ge 30 ] && echo 'Cannot get clusterip, failed to create pvc' && exit 1
done 

# create pv
cat pv.yaml | envsubst '${PV} ${SIZE} ${NS} ${PVC} ${CLUSTER_IP}' | kubectl apply -f -

# wait for service to be ready
SECONDS=0
ENDPOINTS=
while [ -z "${ENDPOINTS}" ] ; do
    ENDPOINTS="$( kubectl -n volume-nfs get ep "$PV" -o jsonpath='{.subsets[0].addresses[0].ip}' )"
    sleep 1
    [ "${SECONDS}" -ge 300 ] && echo 'Cannot get endpoints, please check volume-nfs pod' && exit 1
done 

echo "PVC ${PVC} is Ready!"

kubectl -n "$NS" get pvc "$PVC"
