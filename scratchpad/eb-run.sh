#!/bin/sh
# $1 = build dir, $2 = tag, $3... = flags under test
S=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
D=$1; TAG=$2; shift 2
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$HOME/src/nixos-configuration/dep/nixpkgs" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "sh $S/eb-conf.sh $D $*" > "$S/$TAG.out" 2> "$S/$TAG.err"
echo "configure rc=$?"
echo "--- manifest ---"
ls -l "$D/multi-target.manifest" 2>&1
echo "--- last 15 stderr ---"
tail -15 "$S/$TAG.err"
