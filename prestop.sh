#!/bin/sh -x
exec 1>> /var/lib/volume/nfs/.k8s-prestop.log
exec 2>> /var/lib/volume/nfs/.k8s-prestop.log

nfs_service="volume-nfs@${data_pv}.service"
nsenter -t1 -m -- systemctl stop --no-block "$nfs_service"