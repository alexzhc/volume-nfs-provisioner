#!/bin/sh -x

# get device
data_dev="$( df | grep " ${export_dir}$" | awk '{print $1}' )"
export data_dev

# get export network 
if [ "$export_ip" = '*']; then 
    export_net='*'
elif [ "$export_ip" = '0.0.0.0' ]; then
    export_net='0.0.0.0/0'
else 
    ip_and_netmask="$( ip a | grep "inet $export_ip" | awk '{print $2}' )"
    eval "$( ipcalc -np "$ip_and_netmask" )"
    export_net="${NETWORK}/${PREFIX}"
fi 
export export_net

# set env file
printenv | grep -E nfs_\|data_\|export_\|pod_ | sort > "${export_dir}.env"

# copy export.sh
cp -vuf /usr/bin/export.sh /var/lib/nfs/volume/

# copy volume-nfs.service
[ -n "$( cp -vuf /usr/bin/volume-nfs@.service /etc/systemd/system/ )" ] && \
nsenter -t1 -m -- systemctl daemon-reload

# start volume-nfs.service
nfs_service="volume-nfs@${data_pv}.service"
nsenter -t1 -m -- systemctl start "$nfs_service"

# check for success
let timer=0
until nsenter -t1 -m -- systemctl is-active "$nfs_service"; do
    sleep 1
    let timer++
    [ "$timer" -ge 10 ] && exit 1
done 

# show logs
nsenter -t1 -m -- systemctl status "$nfs_service"

# exit script 
_exit_script() {
    # in case k8s prestop hook fails to execute, make a last-ditch effort to stop volume-nfs.service
    nsenter -t1 -m -- systemctl stop --no-block "$nfs_service"
    exit
}

# main loop
trap _exit_script SIGTERM SIGINT SIGKILL
set +x
while true
do
    sleep 1
done