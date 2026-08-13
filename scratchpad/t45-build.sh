#!/bin/sh
# Task #45/#98 build.  Env: D = build dir (default /tmp/b45), SUB = subdir.
# Derived from t111-build.sh; only SRC and D differ.  The -p set is the
# DEVSHELL-documented known-cached one, byte for byte -- do not extend it.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-add93fb43c802e701
D=${D:-/tmp/b45}
SUB=${SUB:-gcc}
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
  sh_run "cd $D && $SRC/configure --disable-werror \
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

[ -f "$D/gcc/auto-host.h" ] || { echo "FATAL: no gcc/auto-host.h after configure-gcc"; exit 9; }
if grep -n 'define rlim_t' "$D/gcc/auto-host.h"; then
  echo "FATAL: auto-host.h corrupted (see DEVSHELL.md)"; exit 9
fi

sh_run "cd $D/$SUB && make -j8 $*"
