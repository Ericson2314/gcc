#!/bin/sh
# END-TO-END HARNESS for the dtprel probe (task #252).
#
# Same configure line as b-a7b00eeb03e7b153b, from THIS worktree, so that the
# dwarf2out/target.h half of the change is in the cc1 that gets measured.  The
# a7b00 build cannot be reused: it is built from an ancestor commit and lives
# in another agent's worktree.
set -eu
S=/home/jcericson/src/gnu/gcc/multi-target
B=/home/jcericson/src/gnu/gcc/b-t252
I=/home/jcericson/src/gnu/gcc/inst-t252
HDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
J=${J:-16}

mkdir -p "$B"
cd "$B"
if [ ! -f config.status ]; then
  "$S/configure" --disable-werror \
    --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
    --disable-bootstrap --disable-nls \
    --with-native-system-header-dir="$HDR" \
    CC=gcc "CFLAGS=-O2 -g0 -Wno-error=format-security" \
    CXX=g++ "CXXFLAGS=-O2 -g0 -Wno-error=format-security" \
    --enable-languages=c,lto --prefix="$I" > conf.out 2> conf.err
fi
make -j"$J" all-gcc > gcc.log 2> gcc.err
make install-gcc > inst.log 2> inst.err
echo BUILD-OK
