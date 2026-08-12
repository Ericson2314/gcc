#!/usr/bin/env bash
#
# IS (c-DATA) REALLY CONFIG-INVARIANT?
#
# CLASS-C-DESIGN.md 4 splits class (c) into (c-DATA) -- 35 macros, 1824 of the
# 2340 use sites, ZERO new hooks -- and (c-CODE).  The whole cheap path rests on
# one sentence:
#
#     "option state is settled at the end of option processing and does not
#      change again"
#
# so a (c-DATA) macro can become ONE PER-CONFIG SCALAR rather than a call.  8
# of that document names this "the load-bearing unmeasured claim", because
# `__attribute__((target))' and `#pragma GCC target' change i386 option state
# PER FUNCTION.  If `UNITS_PER_WORD' (256 sites) or `Pmode' (646) varies under
# them, the largest and cheapest stage loses its advantage.
#
# WHY NOT MEASURE IT STATICALLY
#
# The tempting instrument is the write set of `cl_target_option_restore' in the
# generated `options-save.cc': that is the complete list of state a per-function
# target attribute can restore.  It was computed (`ix86_isa_flags',
# `target_flags', `ix86_move_max', `ix86_pmode', `ix86_cmodel', `ix86_abi' are
# all in it) and it OVER-APPROXIMATES badly: `move-max=', `cmodel=' and `iamcu'
# are not valid target-attribute arguments at all, so three of those six cannot
# actually be reached that way.  A static answer here would have moved macros to
# the paying side for no reason.
#
# WHAT THIS DOES INSTEAD
#
# A plugin reads each of the 35 macros AT PLUGIN_ALL_PASSES_START -- after
# `targetm.set_current_function' has installed that function's target state,
# i.e. at the same point cc1's own code reads them -- once per function, over a
# generated TU that carries essentially the ENTIRE i386 target-attribute
# vocabulary: every name in the `IX86_ATTR_*' tables and its `no-' form, a
# spread of `arch='/`tune=', all `prefer-vector-width=' and `fpmath=' values,
# `ms_abi', and a `#pragma GCC target' block with a function after the
# `pop_options' (the pragma is the OTHER entry point -- i386-c.cc writes through
# `targetm' at pragma time, i386-options.cc at option-override time).
#
# A macro is INVARIANT only if every function agreed.
#
# CONTROLS, both asserted, neither optional:
#   positive  MOVE_MAX must come out VARIES.  An instrument that has never
#             reported variation has not been shown to be able to.
#   negative  BYTES_BIG_ENDIAN (literal 0 on i386) must come out invariant, or
#             the instrument manufactures variation and every VARIES is noise.
# Plus: the table must be rectangular (every function probed every macro) and
# must cover >= 6 functions, so a run that probed almost nothing cannot pass.
#
# It is run against the STOCK build by default, deliberately: the question is
# about GCC's own per-function target state, not about this branch.
#
# USAGE  scratchpad/cdata-invariance.sh [stock-build] [stock-src]

set -u -o pipefail
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
B=${1:-/tmp/b-stock/gcc}
S=${2:-/tmp/stock-src/gcc}
OUT=${OUT:-/tmp/cdata-out}
HERE=$(cd "$(dirname "$0")" && pwd)

die () { echo "FATAL: $*" >&2; exit 9; }
[ -x "$B/cc1" ] || die "no cc1 at $B/cc1"
[ -d "$S" ] || die "no source dir $S (the plugin must be built against the \
SAME tree the cc1 was built from, or its tm.h is a different target's)"
mkdir -p "$OUT" || die "cannot create $OUT"
rm -f "$OUT/vals.txt" "$OUT/verdict.txt"

nix-shell -I "nixpkgs=$NP" \
  -p gcc binutils gmp.dev mpfr.dev libmpc gawk gnused coreutils diffutils \
  --substituters 'https://cache.nixos.org/' --run '
 set -u; export NIX_HARDENING_ENABLE=
 B='"$B"'; S='"$S"'; OUT='"$OUT"'; HERE='"$HERE"'
 g++ -fPIC -shared -o $OUT/cdata.so $HERE/cdata-invariance-plugin.cc \
   -DIN_GCC -DHAVE_CONFIG_H -I$B -I$S -I$S/../include -I$S/../libcpp/include \
   -I$S/../libcody -I$S/../libdecnumber -I$S/../libdecnumber/bid \
   -I$B/../libdecnumber -I$S/../libbacktrace -std=c++14 -w \
   > $OUT/plugin.out 2> $OUT/plugin.err \
   || { cat $OUT/plugin.err; echo "FATAL: plugin did not build"; exit 9; }
 ( cd $B && CDATA_OUT=$OUT/vals.txt ./cc1 -quiet -nostdinc -O2 -mavx512f -msse4.2 \
     -fplugin=$OUT/cdata.so $HERE/cdata-invariance-sweep.c -o $OUT/sweep.s ) \
   > $OUT/cc1.out 2> $OUT/cc1.err \
   || { cat $OUT/cc1.err; echo "FATAL: cc1 failed"; exit 9; }
 grep -q "error:" $OUT/cc1.err && { cat $OUT/cc1.err; echo "FATAL: errors in the sweep TU; with errors GCC never runs the passes, so the plugin would report nothing"; exit 9; }
 exit 0
' || die "probe run failed"

[ -s "$OUT/vals.txt" ] || die "the plugin wrote nothing; an empty table must \
not read as 'everything is invariant'"

NFN=$(cut -d'|' -f1 "$OUT/vals.txt" | sort -u | wc -l)
NMA=$(cut -d'|' -f2 "$OUT/vals.txt" | sort -u | wc -l)
NEX=$(grep -vc '^#' "$HERE/cdata-macro-list.txt")
echo "functions probed: $NFN   macros probed: $NMA   rows: $(wc -l < "$OUT/vals.txt")"
[ "$NFN" -ge 6 ] || die "only $NFN functions -- per-function variation is not \
observable in this run"
[ "$NMA" -eq "$NEX" ] || die "$NMA macros probed, expected $NEX"
[ "$(wc -l < "$OUT/vals.txt")" -eq $((NFN * NMA)) ] \
  || die "ragged table: some function did not report some macro, and a missing \
row would silently read as agreement"

awk -F'|' '{k=$2; v=$3"="$4
            if (!(k in seen)) { seen[k]=v; ord[++n]=k }
            if (seen[k]!=v) vary[k]=1
            vals[k]=vals[k] " " $4 }
     END { for (i=1;i<=n;i++) { k=ord[i]
             if (k in vary) {
               m=split (vals[k], a, " "); delete u; s=""
               for (j=1;j<=m;j++) if (!(a[j] in u)) { u[a[j]]=1; s=s " " a[j] }
               printf "%-30s VARIES   {%s }\n", k, s
             } else printf "%-30s invariant\n", k } }' "$OUT/vals.txt" \
  > "$OUT/verdict.txt"
cat "$OUT/verdict.txt"

echo "--- controls"
grep -qE '^MOVE_MAX +VARIES' "$OUT/verdict.txt" \
  || die "positive control: MOVE_MAX is known to widen under target(\"avx512f\") \
and was reported invariant.  This instrument has never demonstrated it can \
report variation, so every 'invariant' above is unfalsifiable."
grep -qE '^BYTES_BIG_ENDIAN +invariant' "$OUT/verdict.txt" \
  || die "negative control: BYTES_BIG_ENDIAN is a literal 0 on i386 and was \
reported as varying.  The instrument manufactures variation."
echo "ok: MOVE_MAX=VARIES and BYTES_BIG_ENDIAN=invariant -- both directions are \
reachable, so each verdict above is a measurement"
echo "--- totals: $(grep -c VARIES "$OUT/verdict.txt") vary, \
$(grep -c invariant "$OUT/verdict.txt") invariant, of $NMA"
