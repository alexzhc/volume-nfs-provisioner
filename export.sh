#!/bin/bash -x
opt="$1"
basename="$2"
[ -z "${basename}" ] && echo "Must provide a mountpoint basename" && exit 1

case "$opt" in 
    -r)
        echo "This export is originally for target PVC \"${nfs_pvc}\" in namespace \"${nfs_ns}\""
        # export
        sed -i "/${basename}/d" /etc/exports
        echo "${export_dir} ${export_ip}/${export_mask}(${export_opt})" >> /etc/exports    
        exportfs -vr
        showmount -e "${export_ip}" | grep "${export_dir}" || exit 1
        ;;
    -u)
        # unexport
        sed -i "/${basename}/d" /etc/exports
        exportfs -vrf
        # make sure unmount
        SECONDS=0
        while [ "$SECONDS" -lt 120 ] ; do 
            findmnt "${data_dev}" || break
            umount -vAf "${data_dev}" && break
        done
        ;;
    *)
        echo "Bad Argument"
        exit 1
        ;;
esac
