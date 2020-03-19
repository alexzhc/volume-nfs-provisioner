#!/bin/bash -x
OPT="$1"
BASENAME="$2"
[ -z "${BASENAME}" ] && echo "Must provide a mountpoint basename" && exit 1

# get device and mountpoint
DEV_PV="$( /var/lib/kubelet/pods/${POD_UID}/volumeDevices/kubernetes.io~csi )"
DEV_NUM="$( ls -l /var/lib/kubelet/plugins/kubernetes.io/csi/volumeDevices/publish/${DEV_PV} | awk '{print $5", "$6}' )"
DEV="$( ls -ld /dev/* | awk "/${DEV_NUM}/ { print \$NF }" )"
EXPORT_DIR="/var/lib/volume/nfs/${BASENAME}"

case "$OPT" in 
    -r)   
        # mount
        [ -z "$( blkid "${DEV}" )" ] && mkfs.xfs "${DEV}"
        mkdir -vp "${EXPORT_DIR}"
        mount -v -o sync,noatime "${DEV}" "${EXPORT_DIR}"
        # export
        sed -i "/${BASENAME}/d" /etc/exports
        echo "${EXPORT_DIR} ${EXPORT_IP}(rw,sync,insecure,no_root_squash,no_subtree_check,crossmnt)" >> /etc/exports    
        exportfs -vr
        showmount -e 127.0.0.1 | grep "${EXPORT_DIR}"
        ;;
    -u)
        # unexport
        sed -i "/${BASENAME}/d" /etc/exports
        exportfs -vrf
        # unmount
        SECONDS=0
        while [ "${SECONDS}" -lt 120 ] ; do 
            findmnt "${DEV}" || break
            umount -vAf "${DEV}" && break
        done
        ;;
    *)
        echo "Bad Argument"
        exit 1
        ;;
esac
