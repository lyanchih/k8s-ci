FROM alpine:3.4

MAINTAINER Chung Chih, Hung <lyanchih@gmail.com>

RUN apk --no-cache add libvirt-daemon libvirt-qemu qemu qemu-x86_64 qemu-system-x86_64 qemu-img && \
    sed -i -E '/^#(listen_tls|listen_tcp) =/s|#||' /etc/libvirt/libvirtd.conf

COPY libvirtd.entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
