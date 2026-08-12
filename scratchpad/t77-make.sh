#!/bin/sh
set -e
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
cd /tmp/b-77t
make -j8 all-gcc
cd /tmp/b-77t/gcc
make -j8 cc1
make -j8 multi-target-objs
