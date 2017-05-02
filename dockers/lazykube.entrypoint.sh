#!/bin/bash

[ -d /src ] || mkdir /src

cd /src

rm -rf /src/*

git clone http://github.com/lyanchih/LazyKube

cd LazyKube

[ -f "/etc/lazykube/lazy.ini" ] && cp /etc/lazykube/lazy.ini etc/lazy.ini

./scripts/deploy || true

cat -
