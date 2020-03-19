#!/bin/bash -x
OPT="$1"
BASENAME="$2"
[ -z "${BASENAME}" ] && echo "Must provide a mountpoint basename" && exit 1

case "$OPT" in 
    -r)
        echo "This export is originally for target PVC \"${ORIG_TGT_PVC}\" in namespace \"${ORIG_TGT_NS}\""
        # export
        sed -i "/${BASENAME}/d" /etc/exports
        echo "${EXPORT_DIR} ${EXPORT_IP}/${EXPORT_MASK}(${EXPORT_OPT})" >> /etc/exports    
        exportfs -vr
        showmount -e "${EXPORT_IP}" | grep "${EXPORT_DIR}" || exit 1
        ;;
    -u)
        # unexport
        sed -i "/${BASENAME}/d" /etc/exports
        exportfs -vrf
        # make sure unmount
        SECONDS=0
        while [ "${SECONDS}" -lt 120 ] ; do 
            findmnt "${EXPORT_DEV}" || break
            umount -vAf "${EXPORT_DEV}" && break
        done
        ;;
    *)
        echo "Bad Argument"
        exit 1
        ;;
esac
