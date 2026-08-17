#!/bin/sh
# Drive the identity harness under the dev shell, with the per-target flags the
# TOP LEVEL passes today (awked out of gcc/multi-target.manifest).  Set
# MT_LEGACY=no to drop them, which is what the post-change run must do.
set -eu
S=/home/jcericson/src/gnu/gcc/multi-target
B=/home/jcericson/src/gnu/gcc/build/mt-hdr
O=${1:?outdir}
LEG=${MT_LEGACY:-yes}
if [ "$LEG" = yes ]; then
  AA_EXTRA="--with-cpu-type=aarch64 --with-option-defaults= --with-decimal-float=1 --with-decimal-bid-format=1 --with-shared-libgcc=yes"
  AR_EXTRA="--with-cpu-type=arm '--with-option-defaults=cpu=arm10e float=hard tls=gnu' --with-decimal-float=0 --with-decimal-bid-format=0 --with-shared-libgcc=yes"
  X8_EXTRA="--with-cpu-type=i386 '--with-option-defaults=cpu=generic arch=x86-64' --with-decimal-float=1 --with-decimal-bid-format=1 --with-shared-libgcc=yes"
else
  AA_EXTRA=; AR_EXTRA=; X8_EXTRA=
fi
export AA_EXTRA AR_EXTRA X8_EXTRA
sh "$S/scratchpad/eb-shell.sh" "sh $S/scratchpad/a302b44ba-t249-specsid.sh $O"
