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
#
# ---------------------------------------------------------------------------
# FALSE GREEN FIXED 2026-08-11.  A *relative* IN (the documented
# `IN=scratchpad/big.c') produced no .s files at all, and the NEGATIVE CONTROL
# still printed "ok, differs" -- because `cmp -s' on two NONEXISTENT files
# exits non-zero, which this script read as "they differ", i.e. as success.
# The "distinct md5 among 5 outputs" line printed 0 and was likewise not scored.
#
# The cause was NOT that nix-shell loses cwd (it does not -- measured).  It is
# the `cd $MT/gcc' in the compile loop: the guard `[ -s "$IN" ]' ran in the
# original cwd where the relative path resolved, and cc1 then ran somewhere
# else where it did not.  A guard that validates a path in a different
# directory from the one that uses it is not a guard.
#
# Invariants now enforced, each failing BY NAME:
#   * IN and OUT are made ABSOLUTE in the outer shell, before anything cds.
#     A relative path therefore either works or fails naming itself.
#   * Every operand of every comparison must exist and be non-empty BEFORE the
#     comparison is scored; an unscorable level is a failure, never a pass.
#   * Exactly 5 levels must be scored.  Compiling nothing cannot report success.
#   * The negative control asserts it is comparing two REAL, DISTINCT,
#     NON-EMPTY artefacts, and only then that their contents differ.
#   * The distinct-md5 counts are asserted (all 5 outputs must be present, and
#     at least 2 hashes distinct), not merely printed.
# ---------------------------------------------------------------------------
set -u -o pipefail
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
IN=${IN:-/tmp/acc2/t.c}
OUT=${OUT:-/tmp/stockcmp}
MT=${MT:-/tmp/b-objs}
ST=${ST:-/tmp/b-stock}

# Absolutise in the OUTER shell, where a relative path still means what the
# caller meant.  Fail by name rather than letting a later `cd' silently change
# what the path denotes.
[ -e "$IN" ] || { echo "FATAL: input does not exist (as given, relative to $PWD): $IN"; exit 9; }
IN=$(readlink -f -- "$IN") || { echo "FATAL: cannot absolutise IN"; exit 9; }
case $IN in /*) ;; *) echo "FATAL: IN did not absolutise: $IN"; exit 9;; esac
mkdir -p -- "$OUT" || { echo "FATAL: cannot create OUT $OUT"; exit 9; }
OUT=$(readlink -f -- "$OUT") || { echo "FATAL: cannot absolutise OUT"; exit 9; }
case $OUT in /*) ;; *) echo "FATAL: OUT did not absolutise: $OUT"; exit 9;; esac
case $MT in /*) ;; *) echo "FATAL: MT must be an absolute path: $MT"; exit 9;; esac
case $ST in /*) ;; *) echo "FATAL: ST must be an absolute path: $ST"; exit 9;; esac
echo "input  : $IN"
echo "outdir : $OUT"

nix-shell -I "nixpkgs=$NP" -p coreutils diffutils --substituters 'https://cache.nixos.org/' --run '
 set -u
 for t in cmp md5sum wc readlink; do command -v $t >/dev/null || { echo "FATAL missing $t"; exit 9; }; done
 IN='"$IN"'; OUT='"$OUT"'; MT='"$MT"'; ST='"$ST"'
 # Re-assert absoluteness inside the shell: everything below cds.
 for p in "$IN" "$OUT" "$MT" "$ST"; do
   case $p in /*) ;; *) echo "FATAL: non-absolute path reached the compile loop: $p"; exit 9;; esac
 done
 [ -s "$IN" ] || { echo "FATAL: empty or missing input $IN"; exit 9; }
 [ "$(wc -l < $IN)" -ge 5 ] || { echo "FATAL: input has fewer than 5 lines; a trivial input can match by accident"; exit 9; }
 [ -x "$MT/gcc/cc1" ] || { echo "FATAL: no multi-target cc1 at $MT/gcc/cc1"; exit 9; }
 [ -x "$ST/gcc/cc1" ] || { echo "FATAL: no stock cc1 at $ST/gcc/cc1"; exit 9; }
 rm -rf "$OUT"; mkdir -p "$OUT" || { echo "FATAL: cannot recreate $OUT"; exit 9; }
 # THE CONFIG FILE MOVED, AND ITS ABSENCE LOOKED LIKE A COMPILER BUG.
 #
 # NO APOSTROPHE MAY APPEAR ANYWHERE BELOW THIS LINE, INCLUDING IN COMMENTS.
 # Everything from the --run down to the final quote is ONE single-quoted
 # argument.  A GCC-style quote character in a COMMENT ends that argument, and
 # the words after it leave the string and become extra nix-shell -p packages.
 # Measured: this file had two such characters, nix-shell died with
 # "undefined variable a" (from the comment text "a RELATIVE name"), and THE
 # REST OF THE SCRIPT THEN RAN IN THE OUTER SHELL, outside nix-shell entirely.
 # It still printed 5/5 IDENTICAL with the negative control firing, so the
 # defect was invisible in the RESULT and visible only on stderr, which nobody
 # read.  Section 5 of PRINCIPLES, committed inside the acceptance bar itself.
 # A first attempt to document it re-broke it the same way, with the words
 # "closing quote": assert the stderr is EMPTY, do not eyeball this.
 # This was -ftarget-config=specs-x86_64-pc-linux-gnu-config, a RELATIVE name
 # in $MT/gcc.  #119 deliberately stopped linking the config file into gcc/
 # (only the spec file is linked; see Makefile.tpl), so in any build dir made
 # since, all five levels died with
 #
 #   internal compiler error: no target configuration was selected, so there
 #   is no register vocabulary to initialise
 #
 # -- which is the driver-less cc1 REFUSING CORRECTLY, i.e. the compiler
 # working, reported as five compiler failures.  Absolute, overridable, and
 # checked BY NAME before anything runs, so a missing config can never again
 # be read as a code defect.
 MTCFG=${MTCFG:-$(ls -1 $MT/lib/gcc/*/x86_64-pc-linux-gnu/specs-config 2>/dev/null | head -1)}
 [ -n "$MTCFG" ] && [ -s "$MTCFG" ] || {
   echo "FATAL: no x86_64 target config for the multi-target build."
   echo "       looked for $MT/lib/gcc/*/x86_64-pc-linux-gnu/specs-config"
   echo "       run the target-specs configure for x86_64 first, or set MTCFG."
   exit 9; }
 echo "mt cfg : $MTCFG"
 rc=0
 for O in 0 1 2 3 s; do
   (cd $MT/gcc && ./cc1 -quiet -nostdinc -O$O \
      -ftarget-config="$MTCFG" "$IN" -o $OUT/mt-O$O.s) \
      > $OUT/mt-O$O.log 2>&1 || { echo "mt -O$O FAILED"; cat $OUT/mt-O$O.log; rc=1; }
   (cd $ST/gcc && ./cc1 -quiet -nostdinc -O$O "$IN" -o $OUT/stock-O$O.s) \
      > $OUT/stock-O$O.log 2>&1 || { echo "stock -O$O FAILED"; cat $OUT/stock-O$O.log; rc=1; }
 done

 # A file is a usable operand only if it EXISTS, is non-empty, and is long
 # enough that an accidental match is not plausible.  Anything else is a
 # failure of the arm, not a level that is quietly skipped.
 usable () {   # usable <file> <label>
   if   [ ! -e "$1" ];                     then echo "    $2 MISSING: $1"; return 1
   elif [ ! -s "$1" ];                     then echo "    $2 EMPTY: $1";   return 1
   elif [ "$(wc -l < $1)" -lt 20 ];        then echo "    $2 TOO SHORT (<20 lines): $1"; return 1
   fi
   return 0
 }

 echo "--- per level"
 scored=0
 identical=0
 for O in 0 1 2 3 s; do
   a=$OUT/mt-O$O.s; b=$OUT/stock-O$O.s
   ok=1
   usable "$a" "-O$O mt"    || ok=0
   usable "$b" "-O$O stock" || ok=0
   if [ $ok -eq 0 ]; then
     echo "-O$O UNSCORABLE -- not compared, counts as failure"
     rc=1
     continue
   fi
   scored=$((scored+1))
   if cmp -s $a $b; then v=IDENTICAL; identical=$((identical+1)); else v=DIFFER; rc=1; fi
   echo "-O$O $v  mt_lines=$(wc -l < $a) stock_lines=$(wc -l < $b) mt_md5=$(md5sum < $a | cut -c1-12) stock_md5=$(md5sum < $b | cut -c1-12)"
   [ "$v" = DIFFER ] && { echo "    first differences:"; diff $b $a | head -20 | sed "s/^/    /"; }
 done
 echo "--- levels scored: $scored/5   identical: $identical/5"
 [ $scored -eq 5 ] || { echo "FATAL: only $scored of 5 levels were comparable -- this run proves nothing"; rc=1; }

 echo "--- the outputs are not one file compared with itself:"
 for side in mt stock; do
   n=$(ls $OUT/$side-O0.s $OUT/$side-O1.s $OUT/$side-O2.s $OUT/$side-O3.s $OUT/$side-Os.s 2>/dev/null | wc -l)
   if [ "$n" -ne 5 ]; then
     echo "    FATAL: $side produced $n of 5 outputs; distinctness is not measurable"; rc=1; continue
   fi
   d=$(md5sum $OUT/$side-O0.s $OUT/$side-O1.s $OUT/$side-O2.s $OUT/$side-O3.s $OUT/$side-Os.s | cut -d\  -f1 | sort -u | wc -l)
   echo "    distinct md5 among 5 $side outputs: $d"
   [ "$d" -ge 2 ] || { echo "    FATAL: all 5 $side outputs hash the same; the -O levels are not doing anything"; rc=1; }
 done

 echo "--- NEGATIVE CONTROL: mt -O0 vs stock -O2 must DIFFER"
 nca=$OUT/mt-O0.s; ncb=$OUT/stock-O2.s
 ncok=1
 usable "$nca" "negctl A" || ncok=0
 usable "$ncb" "negctl B" || ncok=0
 if [ "$nca" = "$ncb" ]; then echo "    FATAL: negative control compares a file with itself"; ncok=0; fi
 if [ $ncok -eq 0 ]; then
   echo "    FATAL: negative control had no real operands -- it asserts NOTHING"
   rc=1
 elif cmp -s "$nca" "$ncb"; then
   echo "    FATAL: negative control matched"; rc=1
 else
   echo "    ok: two real, non-empty, distinct artefacts ($(wc -l < $nca) and $(wc -l < $ncb) lines) that differ"
 fi
 echo "OVERALL rc=$rc"
 exit $rc
'
