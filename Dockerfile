FROM busybox

COPY cmd/ /usr/bin/

ENTRYPOINT [ "entry.sh" ]