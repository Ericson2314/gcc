#!/bin/sh
# Task #107: MEASURE sizeof/alignof CUMULATIVE_ARGS per configured base.
#
# Compile-only + `nm -S', the multi-target-reg-probe.cc trick, so the answer is
# correct without running anything.  The array is declared one byte longer than
# the value so that "0" and "nm printed nothing" are different outcomes.
#
# Every way of learning nothing is a failure: missing -inc dir, empty object,
# symbol nm did not print, non-numeric size -- each fatal and named.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b107}
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a14027402aa930aca
W=/tmp/t107-size
mkdir -p "$W"
cat > "$W/probe.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
extern "C" {
char mt_probe_cumulative_args_size[sizeof (CUMULATIVE_ARGS) + 1];
char mt_probe_cumulative_args_align[alignof (CUMULATIVE_ARGS) + 1];
}
EOF
run () {
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake binutils gmp.dev mpfr.dev libmpc \
    --substituters 'https://cache.nixos.org/' --run "$1"
}
for b in i386 aarch64; do
  [ -d "$D/gcc/$b-inc" ] || { echo "FATAL: no $D/gcc/$b-inc"; exit 9; }
  o="$W/$b.o"
  rm -f "$o"
  run "cd $D/gcc && g++ -c -DIN_GCC -DHAVE_CONFIG_H -fno-exceptions -fno-rtti \
      -I$b-inc -I. -I$SRC/gcc -I$SRC/include -I$SRC/libcpp/include \
      -I$SRC/libdecnumber -I../libdecnumber -I$SRC/libbacktrace \
      -o $o $W/probe.cc" || { echo "FATAL: $b probe did not compile"; exit 9; }
  [ -s "$o" ] || { echo "FATAL: $b probe object empty"; exit 9; }
  syms=$(run "nm -S $o") || { echo "FATAL: nm failed on $o"; exit 9; }
  for s in mt_probe_cumulative_args_size mt_probe_cumulative_args_align; do
    line=$(echo "$syms" | grep " $s\$") || line=
    [ -n "$line" ] || { echo "FATAL: $o defines no $s"; exit 9; }
    hex=$(echo "$line" | awk '{print $2}')
    case $hex in [0-9a-fA-F]*) ;; *) echo "FATAL: $s no size ($line)"; exit 9;; esac
    v=$(( $(printf '%d' "0x$hex") - 1 ))
    [ "$v" -gt 0 ] || { echo "FATAL: $b $s measured $v"; exit 9; }
    echo "$b $s = $v"
  done
done
