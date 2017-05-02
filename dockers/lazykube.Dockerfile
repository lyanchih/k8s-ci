FROM ubuntu:16.04

MAINTAINER Chung Chih, Hung <lyanchih@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive

ENV REPLACE_NET=

RUN apt-get update && apt-get install -y libvirt-bin docker.io virt-manager openssh-client make curl git bridge-utils qemu-system-x86 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY lazykube.entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
