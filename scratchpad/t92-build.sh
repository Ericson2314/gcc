#!/bin/sh
# Task #92 build.  A COPY of rv-build.sh with SRC pointing at this worktree --
# not a shared build dir, and not a shared source tree.  PRINCIPLES 5: "in a
# shared build dir, a file you did not write is not a fixture".
#
# Env: D = build dir (default /tmp/b-92), SUB = subdir to make in (default gcc).
# Args: make targets.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-ad7bedb1b502388f7
D=${D:-/tmp/b-92}
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
