#!/bin/sh
# #208 -- are the 7 `maybe_record_trace_start' ICEs gone, and did THIS change
# have anything to do with it?
#
# The two reproducers are the ones named in A446B256F0B8BB99C-FINDINGS.md as
# carrying these ICEs in the surviving log, at `-O2 -g'.
#
# RUN AGAINST BOTH COMPILERS, because "gone" and "gone BECAUSE OF THIS FIX"
# are different claims and the honest answer may be that #194 already did it.
# A one-sided run cannot distinguish them and would let this task bank someone
# else's result.
#
# `-g' MATTERS AND IS NOT DECORATION.  `dwarf2out_do_frame' returns true for
# `dwarf_debuginfo_p ()' regardless of the unwind method, so the dwarf2 CFI
# pass RUNS at -g even when `except_unwind_info' says UI_SJLJ -- i.e. the #208
# bug did not suppress this ICE, and would not have masked it either way.
set -u
A=${A:?pre-fix build dir}
B=${B:?post-fix build dir}
SRC=${SRC:?snapshot}
V=17.0.0
W=${W:-/tmp/w-a62563d5673423af6-ice}
mkdir -p "$W"

for t in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  for f in shrink-wrap-sibcall pr59418; do
    IN=$SRC/gcc/testsuite/gcc.dg/$f.c
    [ -f "$IN" ] || { echo "FATAL: no $IN"; exit 9; }
    line=""
    for s in a b; do
      case $s in a) D=$A ;; b) D=$B ;; esac
      CFG=$D/lib/gcc/$V/$t/specs-config
      [ -s "$CFG" ] || { echo "$t: FATAL no $CFG"; exit 9; }
      ( cd "$W" && "$D/gcc/cc1" -quiet -nostdinc -O2 -g -ftarget-config="$CFG" \
          "$IN" -o "$W/$s-$t-$f.s" ) > "$W/$s-$t-$f.out" 2> "$W/$s-$t-$f.err"
      r=$?
      # An ICE is named, not inferred from rc: rc!=0 also covers a plain error.
      ice=$(sed -n 's/.*internal compiler error: \(.*\)/\1/p' "$W/$s-$t-$f.err" | head -1)
      mrts=$(grep -c 'maybe_record_trace_start' "$W/$s-$t-$f.err" || true)
      if [ -n "$ice" ]; then
        line="$line  $s:rc=$r ICE[$ice] mrts=$mrts"
      else
        line="$line  $s:rc=$r no-ICE mrts=$mrts"
      fi
    done
    printf '%-28s %-22s%s\n' "$t" "$f" "$line"
  done
done
