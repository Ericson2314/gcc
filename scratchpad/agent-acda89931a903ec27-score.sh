#!/bin/sh
# Score `gcc.target/<cpu>' once per back end, WRITING EACH ROW AS IT LANDS.
#
# Rows are appended to $OUT/rows.txt immediately after each target finishes,
# not accumulated to the end: if the machine takes the run down, a partial
# board with stamped rows is worth far more than a complete one that never
# gets reported.
#
# `gcc.target/<cpu>' is the point of the exercise -- it is where
# `scan-assembler' divergence lives, and it was deliberately EXCLUDED from the
# last sweep's subset for cross-target comparability.  Here it is the subset.
#
# THE THREE FAILURE VERDICTS ARE KEPT DISTINCT, because collapsing them is
# what made the last table need redoing.  They are different findings:
#
#   NO-CROSS-AS        no verified `<triple>-as' exists       (nvptx, gcn)
#   NO-SPECS           target-specs produced no specs-config
#   NO-EXP             upstream has no gcc.target directory for this back end
#   DIED-FIRST-INPUT   cc1 dies on its first input -- NO FAIL ROWS AT ALL,
#                      which is invisible to a .sum-based ranking and looks
#                      identical to a back end that passed everything
#   SCORED             a .sum exists and was stamped
#
# THE PRECONDITION THAT MAKES `DIED-FIRST-INPUT' VISIBLE is the one-line
# census: a back end that dies on its first input produces no FAILs, so a
# `.sum'-based ranking cannot see it and it reads exactly like a pass.  It is
# run BEFORE the suite for every target and its result is carried into the row.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?build dir}
TOOLS=${TOOLS:?verified tools bin dir}
OUT=${OUT:?output dir}
SRCT=${SRCT:?srcdir}
mkdir -p "$OUT"
ROWS="$OUT/rows.txt"
[ -f "$ROWS" ] || echo "# BACKEND TRIPLE VERDICT PASS FAIL LOAD15 KILLED NOTE" > "$ROWS"

VER=$(cat "$SRCT/gcc/BASE-VER")

# backend:triple:expdir  -- expdir empty => upstream has no gcc.target dir
MAP=$(cat "$S/agent-acda89931a903ec27-backends.txt")

for row in $MAP; do
  be=$(echo "$row" | cut -d: -f1)
  T=$(echo "$row"  | cut -d: -f2)
  ex=$(echo "$row" | cut -d: -f3)

  grep -q "^$be " "$ROWS" && { echo "== $be already scored, skipping"; continue; }

  L15=$(cut -d' ' -f3 /proc/loadavg)
  CFG="$B/lib/gcc/$VER/$T/specs-config"

  if [ -z "$ex" ]; then
    printf '%-12s %-30s %-18s %6s %6s %6s %6s %s\n' \
      "$be" "$T" NO-EXP - - "$L15" - "upstream has no gcc.target/$be" >> "$ROWS"
    continue
  fi
  if [ ! -x "$TOOLS/$T-as" ]; then
    printf '%-12s %-30s %-18s %6s %6s %6s %6s %s\n' \
      "$be" "$T" NO-CROSS-AS - - "$L15" - "no GNU as in the concept" >> "$ROWS"
    continue
  fi
  if [ ! -f "$CFG" ]; then
    # NAME THE MISSING ARTEFACT.  "no specs-config" is three different
    # findings and collapsing them makes the table worse than useless.  The
    # known one is m68k: `OPTION_DEFAULT_SPECS' spells its value `-%(VALUE)',
    # the only back end of 22 that does (20 use `-mcpu=%(VALUE)'), and
    # target-specs cannot express it.  That is a ONE-back-end blocker and is
    # recorded as such -- inflating it into a family would be the opposite of
    # the ranking this board exists to produce.
    why=$(grep -m1 -i "$T.*\(cannot\|error\|unsupported\)" "$B/specs.err" 2>/dev/null | cut -c1-80)
    printf '%-12s %-30s %-18s %6s %6s %6s %6s %s\n' \
      "$be" "$T" NO-SPECS - - "$L15" - "${why:-target-specs produced nothing}" >> "$ROWS"
    continue
  fi

  # ---- PRECONDITION: does this back end survive ONE input at all? ----
  printf 'int mt_one (int x) { return x + 1; }\n' > "$OUT/one-$be.c"
  "$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" -S -o "$OUT/one-$be.s" \
      "$OUT/one-$be.c" > "$OUT/one-$be.out" 2> "$OUT/one-$be.err"
  orc=$?
  if [ "$orc" != 0 ]; then
    why=$(head -3 "$OUT/one-$be.err" | tr '\n' ' ' | cut -c1-90)
    printf '%-12s %-30s %-18s %6s %6s %6s %6s %s\n' \
      "$be" "$T" DIED-FIRST-INPUT - - "$L15" - "rc=$orc $why" >> "$ROWS"
    continue
  fi

  # ---- the suite ----
  TV=MT_TOOLS_$(printf '%s' "$T" | tr - _)
  env "$TV=$TOOLS" MT_COMPILE_ONLY=1 MT_RUNTESTFLAGS="$ex" \
      MT_MAKEFLAGS="-j${MT_SUITE_JOBS:-2}" \
      sh "$S/mtcheck.sh" "$B" "$T" > "$OUT/check-$be.out" 2>&1
  crc=$?

  SUM="$B/gcc/testsuite.$T/gcc/gcc.sum"
  if [ -f "$B/check-$T.rc" ] && [ -f "$SUM" ]; then
    # BOTH artefacts, copied immediately.  mtcheck.sh writes every run to the
    # same gcc.sum/gcc.log, so the NEXT target destroys this one's -- and a
    # destroyed file reads as a present one.  The `.rc' stamp says a run
    # finished; it does not say the file still belongs to that run.
    cp "$SUM" "$OUT/gcc-$be.sum"
    [ -f "$B/gcc/testsuite.$T/gcc/gcc.log" ] \
      && cp "$B/gcc/testsuite.$T/gcc/gcc.log" "$OUT/gcc-$be.log"
    p=$(grep -c '^PASS:' "$OUT/gcc-$be.sum")
    f=$(grep -c '^FAIL:' "$OUT/gcc-$be.sum")
    k=$(grep -ci 'killed\|Killed' "$OUT/check-$be.out" || true)
    L15b=$(cut -d' ' -f3 /proc/loadavg)
    prov=""
    awk -v l="$L15b" 'BEGIN{exit !(l>25)}' && prov="PROVISIONAL(load>25)"
    printf '%-12s %-30s %-18s %6s %6s %6s %6s %s\n' \
      "$be" "$T" SCORED "$p" "$f" "$L15b" "$k" "$prov" >> "$ROWS"
  else
    why=$(grep -m1 'FATAL' "$OUT/check-$be.out" | cut -c1-90)
    printf '%-12s %-30s %-18s %6s %6s %6s %6s %s\n' \
      "$be" "$T" NO-SUM - - "$L15" - "crc=$crc ${why:-no gcc.sum and no stamp}" >> "$ROWS"
  fi
done
echo "== rows so far:"; cat "$ROWS"
