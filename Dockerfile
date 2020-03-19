FROM alpine AS pm

RUN set -x && \
    apk fetch --no-cache --update nfs-utils

RUN set -x && \
    mv -v nfs-utils*.apk /tmp/ && \
    cd /tmp/ && \
    tar -zxvf nfs-utils*.apk && \
    mv -vf /tmp/usr/sbin/exportfs /usr/sbin && \
    rm -vfr /tmp/* /var/cache/apk/*


