#!/bin/sh

set -e

# NOTE(lyanchih) virtlogd will probablly running after container destroy
if [ -f /var/run/virtlogd.pid ]; then
    kill $(cat /var/run/virtlogd.pid) || true
fi

# NOTE(lyanchih) libvirt version after 1.16 mandatory virtlog daemon
virtlogd -d

libvirtd -l
