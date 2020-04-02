#!/bin/sh -ax

nfs_sts="$1"
data_pvc="$2"
data_pv="$3"

nfs_pvc="$4"
nfs_pv="$5"
nfs_ns="$6"
# nfs_ns=default

exec 3>&1 1>&2

envsubst < tmpl/nfs-sts.yaml | kubectl apply -f -

# wait for service endpoints to be ready
SECONDS=0
endpoints=
while [ -z "$endpoints" ] ; do
    endpoints="$( kubectl -n volume-nfs get ep "$nfs_sts" -o jsonpath='{.subsets[0].addresses[0].ip}' )"
    sleep 3
    [ "$SECONDS" -ge 60 ] && echo 'Cannot get endpoints, please check volume-nfs pod' && exit 0
done 

exec 1>&3 3>&-

printf "${nfs_ns}/${nfs_sts}"