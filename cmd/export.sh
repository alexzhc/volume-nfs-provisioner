#!/bin/bash -x
opt="$1"
basename="$2"
[ -z "${basename}" ] && echo "Must provide a mountpoint basename" && exit 1

echo "
NFS PVC     : ${nfs_ns}/${nfs_pvc}
NFS PV      : ${nfs_pv}
NFS POD     : volume-nfs/${pod_name}
Data PVC    : volume-nfs/${data_pvc}
Data PV     : ${data_pv}
Data Dev    : ${data_dev}
Export Net  : ${export_net}
Export Dir  : ${export_dir}
"

_export_vol() {
    mountpoint "$export_dir" || exit 1
    # export
    sed -i "/${basename}/d" /etc/exports
    echo "${export_dir} ${export_net}(${export_opt})" >> /etc/exports    
    exportfs -vr
    showmount -e "$export_ip" | grep "$export_dir" || exit 1
}

_unexport_vol() {
    # unexport
    sed -i "/${basename}/d" /etc/exports
    exportfs -vrf
    # make sure unmount
    SECONDS=0
    while [ "$SECONDS" -lt 120 ] ; do 
        findmnt "$data_dev" || break
        umount -vAf "${data_dev}" && break
    done
}

_cleanup_mount() {
    rmdir -v "$export_dir" 
    rm -vf "${export_dir}.env"
}

case "$opt" in 
    -r) 
        _export_vol 
        ;;
    -u) 
        _unexport_vol 
        ;;
    -c)
        _unexport_vol
        _cleanup_mount
        ;;  
    *)
        echo "Bad Argument"
        exit 1
        ;;
esac
