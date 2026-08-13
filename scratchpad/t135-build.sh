#!/bin/sh
# Task #59 build.  Env: D = build dir (default /tmp/b135), SUB = subdir to
# make in (default gcc).  Args: make targets.
#
# The -p set is the DEVSHELL-documented known-cached one, byte for byte.
# binutils is deliberately NOT in it: adding it put nix's unwrapped ld.bfd on
# PATH and configure's link probes then failed with `cannot find -lgcc'.
# Use a separate shell for `nm'.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-ab8de4ba7cc574176
D=${D:-/tmp/b135}
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
  sh_run "cd $D && $SRC/configure --disable-werror --prefix=$D \
      --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
      --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
      --disable-bootstrap --disable-nls \
      --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
      CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
      CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
      --enable-languages=c,lto" || exit $?
fi

# gcc/ is configured by the top level, not by `make -C gcc'.  Doing this
# unconditionally is cheap and avoids the "No such file or directory" that
# reads like a broken tree.
# The HOST libraries cc1 links (libcpp, libiberty, libdecnumber, libbacktrace)
# and the BUILD ones the generators link are top-level targets; `make -C gcc'
# builds none of them and reports the miss as
# `No rule to make target ../libcpp/libcpp.a', which reads like a broken tree.
if [ ! -f "$D/gcc/Makefile" ] || [ ! -f "$D/libcpp/libcpp.a" ]; then
  sh_run "cd $D && make -j8 all-build-libiberty all-build-libcpp \
      all-libiberty all-libcpp all-libdecnumber all-libbacktrace all-zlib \
      configure-gcc" || exit $?
fi

# The rlim_t check from DEVSHELL.md.  It can only run once gcc/ is configured;
# running it earlier greps a file that does not exist yet and `grep' failing to
# open a file is not evidence the file is clean.
[ -f "$D/gcc/auto-host.h" ] || { echo "FATAL: no gcc/auto-host.h after configure-gcc"; exit 9; }
if grep -n 'define rlim_t' "$D/gcc/auto-host.h"; then
  echo "FATAL: auto-host.h corrupted (see DEVSHELL.md)"; exit 9
fi

sh_run "cd $D/$SUB && make -j8 $*"
