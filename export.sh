#!/bin/bash -x
opt="$1"
basename="$2"
[ -z "${basename}" ] && echo "Must provide a mountpoint basename" && exit 1
echo "This export is originally for target PVC \"${nfs_pvc}\" in namespace \"${nfs_ns}\""

_export_vol() {
    # export
    sed -i "/${basename}/d" /etc/exports
    if [ "$export_ip" = '*']; then 
        export_ip_mask='*'
    elif [ "$export_ip" = '0.0.0.0' ]; then
        export_ip_mask='0.0.0.0/0'
    else 
        export_ip_mask="$( ip a | grep "inet $ip" | awk '{print $2}' )"
    fi 
    echo "${export_dir} ${export_ip_mask}(${export_opt})" >> /etc/exports    
    exportfs -vr
    showmount -e "${export_ip}" | grep "${export_dir}" || exit 1
}

_unexport_vol() {
    # unexport
    sed -i "/${basename}/d" /etc/exports
    exportfs -vrf
    # make sure unmount
    SECONDS=0
    while [ "$SECONDS" -lt 120 ] ; do 
        findmnt "${data_dev}" || break
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
