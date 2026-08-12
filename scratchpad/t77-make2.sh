#!/bin/sh
set -e
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
# target-specs SILENTLY SKIPS a target whose <triple>-as/-ld is not on PATH,
# and then no driver can select it -- see DEVSHELL.md.  aarch64 is the
# non-primary base this task has to exercise, so its stubs go on PATH.
PATH=/tmp/mt-fakebin:$PATH
export PATH
command -v aarch64-unknown-linux-gnu-as >/dev/null || { echo "FATAL: no aarch64 as stub"; exit 9; }
cd /tmp/b-77t/gcc
rm -f specs-aarch64-unknown-linux-gnu specs-x86_64-pc-linux-gnu
make -j8 cc1
make -j8 multi-target-objs
make target-specs
