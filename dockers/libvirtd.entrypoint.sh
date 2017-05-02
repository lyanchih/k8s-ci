#!/bin/sh

set -e

# NOTE(lyanchih) libvirt version after 1.16 mandatory virtlog daemon
virtlogd -d

libvirtd -l
