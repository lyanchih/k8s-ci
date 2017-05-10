FROM ubuntu:16.04

MAINTAINER Chung Chih, Hung <lyanchih@gmail.com>

RUN apt-get update && apt-get install -y git python-pip libssh-dev curl crudini && pip install ansible pycrypto && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY k8s-helm.entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
