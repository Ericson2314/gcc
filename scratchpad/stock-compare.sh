#!/usr/bin/env bash
#
# ARM 4 -- the multi-target `cc1' against a GENUINE STOCK GCC.
#
# Every comparison this branch has ever run has been against ITSELF.
# /tmp/b-ref1 is this same tree configured for one target; it even requires
# `-ftarget-config=' to run.  So the existing x86_64 byte-identity arm proves
# "adding a second back end does not perturb the first" -- real, and it holds
# at five -O levels -- and proves nothing about unmodified GCC.  A change that
# alters the branch's reference and the branch's multi-target build IDENTICALLY
# is invisible to it, by construction.
#
# This arm closes that.  /tmp/b-stock is upstream GCC at the branch's
# merge-base with master (c31b7a09eea), configured x86_64-only, unmodified.
#
# One configure difference is forced and is recorded rather than hidden:
# stock needs --disable-multilib (this host has no 32-bit libgcc, and stock
# configure fails outright), while the branch does not because it made multilib
# mandatory.  That affects the DRIVER's multilib selection, not the code cc1
# generates for a fixed set of flags, and cc1 is invoked directly here.
#
# -nostdinc is required or cc1 dies on stdc-predef.h before it compiles a line.
set -o pipefail
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
IN=${IN:-/tmp/acc2/t.c}
OUT=${OUT:-/tmp/stockcmp}
MT=${MT:-/tmp/b-objs}
ST=${ST:-/tmp/b-stock}

nix-shell -I "nixpkgs=$NP" -p coreutils diffutils --substituters 'https://cache.nixos.org/' --run '
 set -u
 for t in cmp md5sum wc; do command -v $t >/dev/null || { echo "FATAL missing $t"; exit 9; }; done
 IN='"$IN"'; OUT='"$OUT"'; MT='"$MT"'; ST='"$ST"'
 [ -s "$IN" ] || { echo "FATAL: empty or missing input $IN"; exit 9; }
 [ "$(wc -l < $IN)" -ge 5 ] || { echo "FATAL: input has fewer than 5 lines; a trivial input can match by accident"; exit 9; }
 [ -x "$MT/gcc/cc1" ] || { echo "FATAL: no multi-target cc1"; exit 9; }
 [ -x "$ST/gcc/cc1" ] || { echo "FATAL: no stock cc1"; exit 9; }
 rm -rf "$OUT"; mkdir -p "$OUT"          # delete artefacts before the arm
 rc=0
 for O in 0 1 2 3 s; do
   (cd $MT/gcc && ./cc1 -quiet -nostdinc -O$O \
      -ftarget-config=specs-x86_64-pc-linux-gnu-config "$IN" -o $OUT/mt-O$O.s) \
      > $OUT/mt-O$O.log 2>&1 || { echo "mt -O$O FAILED"; cat $OUT/mt-O$O.log; rc=1; }
   (cd $ST/gcc && ./cc1 -quiet -nostdinc -O$O "$IN" -o $OUT/stock-O$O.s) \
      > $OUT/stock-O$O.log 2>&1 || { echo "stock -O$O FAILED"; cat $OUT/stock-O$O.log; rc=1; }
 done
 echo "--- per level"
 for O in 0 1 2 3 s; do
   a=$OUT/mt-O$O.s; b=$OUT/stock-O$O.s
   for f in $a $b; do
     [ -s "$f" ] || { echo "-O$O FATAL empty $f"; rc=1; }
     [ "$(wc -l < $f 2>/dev/null || echo 0)" -ge 20 ] || { echo "-O$O SUSPICIOUS: $f has < 20 lines"; rc=1; }
   done
   if [ -s "$a" ] && [ -s "$b" ]; then
     if cmp -s $a $b; then v=IDENTICAL; else v=DIFFER; rc=1; fi
     echo "-O$O $v  mt_lines=$(wc -l < $a) stock_lines=$(wc -l < $b) mt_md5=$(md5sum < $a | cut -c1-12) stock_md5=$(md5sum < $b | cut -c1-12)"
     [ "$v" = DIFFER ] && { echo "    first differences:"; diff $b $a | head -20 | sed "s/^/    /"; }
   fi
 done
 echo "--- the outputs are not one file compared with itself:"
 echo "    distinct md5 among 5 mt outputs:    $(md5sum $OUT/mt-O*.s | cut -d\  -f1 | sort -u | wc -l)"
 echo "    distinct md5 among 5 stock outputs: $(md5sum $OUT/stock-O*.s | cut -d\  -f1 | sort -u | wc -l)"
 echo "--- NEGATIVE CONTROL: mt -O0 vs stock -O2 must DIFFER"
 if cmp -s $OUT/mt-O0.s $OUT/stock-O2.s; then echo "FATAL: negative control matched"; rc=1; else echo "    ok, differs"; fi
 echo "OVERALL rc=$rc"
 exit $rc
'
