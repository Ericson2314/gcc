#!/bin/sh
# #119 -- configure a two-target tree for the specs-config connecting rule.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b134}
PFX=${PFX:-/tmp/b134-inst}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
HDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
sh_run () {
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev \
    libmpc texinfo --substituters 'https://cache.nixos.org/' --run "$1"
}

rm -rf "$B"; mkdir -p "$B" || exit 9
sh_run "cd $B && $SRC/configure \
  --prefix=$PFX \
  --disable-werror --disable-bootstrap --disable-nls \
  --enable-targets=$T2,$T1 \
  --enable-backends=$T2,$T1 \
  --with-native-system-header-dir=$HDR \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$B/conf.out" 2> "$B/conf.err"
echo "configure rc=$?"
tail -3 "$B/conf.err"
