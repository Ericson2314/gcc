#!/bin/sh
# #145 -- build the host libraries gcc/ needs, from the TOP LEVEL.
#
# These are libiberty, libcpp, libdecnumber, libbacktrace and the BUILD copy
# of libiberty.  They are independent of which back ends gcc/ was configured
# for, which is what makes it safe to build them before re-running
# gcc/configure with --enable-backends=all.  Building them via the top level
# `all-gcc' would re-run gcc/configure and silently put the 2-back-end list
# back (configure.ac:193 derives it from --enable-targets), so this names the
# library targets explicitly and never asks the top level for gcc.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${D:-/tmp/b-a88fe2f04579b6092}
# `all-build-libcpp' is NOT implied by `all-build-libiberty' and its absence
# does not look like a missing library: the first run failed with
#   make: *** No rule to make target '../build-x86_64-pc-linux-gnu/libcpp/libcpp.a'
# which reads as a broken rule in gcc/ rather than as an unbuilt prerequisite.
sh "$S/eb-shell.sh" "cd $D && make -j8 all-libiberty all-libcpp all-libdecnumber all-libbacktrace all-build-libiberty all-build-libcpp" \
  > "$D/deps.out" 2> "$D/deps.err" || true
for f in libiberty/libiberty.a libcpp/libcpp.a libdecnumber/libdecnumber.a \
         libbacktrace/.libs/libbacktrace.a \
         build-x86_64-pc-linux-gnu/libiberty/libiberty.a \
         build-x86_64-pc-linux-gnu/libcpp/libcpp.a; do
  [ -f "$D/$f" ] || { echo "FATAL: missing $D/$f"; exit 9; }
done
echo "host libraries OK"
