FROM busybox

COPY volume-nfs@.service /

COPY *.sh /usr/bin/

ENTRYPOINT [ "entry.sh" ]