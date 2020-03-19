#!/bin/sh

# set env file 
echo "POD_UID=${THIS_POD_UID} 
EXPORT_IP=0.0.0.0/0.0.0.0" > /opt/piraeus/nfs/env/${BASENAME}
# start systemd to export
SERVICE="piraeus-nfs-export@${BASENAME}.service"
nsenter -t1 -m -- systemctl start "${SERVICE}"
nsenter -t1 -m -- systemctl status "${SERVICE}"

# check for success
nsenter -t1 -m -- systemctl is-active "${SERVICE}" || exit 1

_exit_script() {
    nsenter -t1 -m -- systemctl stop --no-block "${SERVICE}"
    exit
}

# main loop
trap _exit_script SIGTERM SIGINT SIGKILL
while :
do
    sleep 1
done