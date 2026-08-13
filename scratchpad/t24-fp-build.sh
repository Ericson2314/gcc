#!/bin/sh
# Task #24: build a cc1 under a FAKE PREFIX that actually has an <prefix>/include
# directory on disk.
#
# WHY THIS IS NECESSARY.  cc1 -v prints only include directories that EXIST, so
# on this host (NixOS, no /usr/include and no /usr/local/include) the collapsed
# TOOL_INCLUDE_DIR is invisible: the search list comes back empty and a naive
# reading scores that as "the entry is not there".  It is there; nothing on this
# machine can see it.  A green from an environment that structurally cannot show
# the failure is worth nothing, so the failure gets an environment that can.
#
# Env: SRC (source tree), D (build dir), PREFIX (fake prefix).
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=${SRC:?set SRC}
D=${D:?set D}
PREFIX=${PREFIX:?set PREFIX}
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
PKGS="-p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo"

sh_run () {
  nix-shell -I "nixpkgs=$NP" $PKGS \
    --substituters 'https://cache.nixos.org/' --run "$1"
}

if [ ! -f "$D/config.status" ]; then
  mkdir -p "$D"
  n=$(find "$D" -mindepth 1 | wc -l)
  [ "$n" = 0 ] || { echo "FATAL: $D not empty ($n entries) and not configured"; exit 9; }
  sh_run "cd $D && $SRC/configure --disable-werror --prefix=$PREFIX \
      --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
      --disable-bootstrap --disable-nls \
      --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
      CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
      CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
      --enable-languages=c,lto" || exit $?
fi

if [ ! -f "$D/gcc/Makefile" ] || [ ! -f "$D/libcpp/libcpp.a" ]; then
  sh_run "cd $D && make -j8 all-build-libiberty all-build-libcpp \
      all-libiberty all-libcpp all-libdecnumber all-libbacktrace all-zlib \
      configure-gcc" || exit $?
fi

[ -f "$D/gcc/auto-host.h" ] || { echo "FATAL: no gcc/auto-host.h"; exit 9; }
if grep -n 'define rlim_t' "$D/gcc/auto-host.h"; then
  echo "FATAL: auto-host.h corrupted (see DEVSHELL.md)"; exit 9
fi

sh_run "cd $D/gcc && make -j8 $*"
