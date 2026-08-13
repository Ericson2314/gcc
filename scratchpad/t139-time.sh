#!/usr/bin/env bash
#
# #139 -- INTERLEAVED A/B THROUGHPUT MEASUREMENT OF TWO `cc1' BINARIES.
#
# The question: what does a converted target macro -- one that used to be a
# compile-time constant and is now a call, at 648 shared sites for `Pmode' --
# cost in compile time?  Output is already known to be byte-identical on both
# bases, so this is a throughput question, and nobody had measured it.
#
# Method, and why each part is here:
#
#  * INTERLEAVED.  Arms alternate A,B,A,B,... within every iteration, not
#    A*N then B*N.  Anything that drifts over the run -- another agent's
#    build starting, thermal behaviour, page cache -- otherwise lands entirely
#    on whichever arm ran second and is indistinguishable from the effect.
#  * N ITERATIONS, ALL PRINTED.  A single timing is not a measurement.  The
#    per-iteration numbers are printed so a reader can see the spread rather
#    than trust a summary statistic, and both MIN and MEDIAN are reported:
#    min is the least noise-contaminated estimate, median the more honest
#    central one, and if they disagree about the sign the run is not
#    conclusive and says so.
#  * WARM-UP ITERATION, discarded, so the first arm is not charged for cold
#    page cache on its own binary.
#  * EQUAL-WORK CHECK.  The two arms' `.s' output is compared file by file.
#    A timing comparison between two compilers doing DIFFERENT work is not a
#    measurement of overhead; if the outputs differ the script says so and
#    refuses to call the delta an overhead.  This is the arm that would catch
#    "B is faster because B stopped optimising".
#  * NON-VACUITY.  Every .s must exist and be >= 20 lines, and the total asm
#    byte count is printed.  A run where cc1 died instantly on everything
#    would otherwise be reported as an enormous speed-up.
#
# usage: t139-time.sh <labelA> <builddirA> <labelB> <builddirB> <corpus> <cfg> <runs>
#   <cfg> is the absolute path to a specs-config file, or the word `none'
#         (only pre-conversion builds that do not require one).
set -u -o pipefail

LA=${1:?labelA}; BA=${2:?builddirA}
LB=${3:?labelB}; BB=${4:?builddirB}
CORPUS=${5:?corpus dir}; CFG=${6:?cfg or none}; RUNS=${7:-11}

for p in "$BA" "$BB" "$CORPUS"; do
  case $p in /*) ;; *) echo "FATAL: path must be absolute: $p"; exit 9;; esac
done
[ -x "$BA/gcc/cc1" ] || { echo "FATAL: no cc1 at $BA/gcc/cc1"; exit 9; }
[ -x "$BB/gcc/cc1" ] || { echo "FATAL: no cc1 at $BB/gcc/cc1"; exit 9; }

shopt -s nullglob
INPUTS=("$CORPUS"/*.i)
[ "${#INPUTS[@]}" -ge 8 ] || { echo "FATAL: corpus has ${#INPUTS[@]} TUs"; exit 9; }
LINES=$(cat "${INPUTS[@]}" | wc -l)
[ "$LINES" -ge 40000 ] || { echo "FATAL: corpus is $LINES lines"; exit 9; }

TCFG=()
if [ "$CFG" != none ]; then
  [ -s "$CFG" ] || { echo "FATAL: target config missing or empty: $CFG"; exit 9; }
  TCFG=(-ftarget-config="$CFG")
fi

OUT=${OUT:-/tmp/a3ab/timing}
mkdir -p "$OUT" || exit 9

echo "A = $LA  $BA/gcc/cc1"
echo "B = $LB  $BB/gcc/cc1"
echo "corpus: ${#INPUTS[@]} TUs, $LINES lines"
echo "config: $CFG"
echo "runs  : $RUNS (plus one discarded warm-up)"

# One pass of the whole corpus through one cc1.  Prints elapsed ns.
# `-o' goes to a per-arm directory so the two arms' output can be compared.
run_arm () {   # run_arm <builddir> <outsubdir>
  local B=$1 D=$2 f b t0 t1 rc=0
  mkdir -p "$OUT/$D"
  t0=$(date +%s%N)
  for f in "${INPUTS[@]}"; do
    b=$(basename "$f" .i)
    "$B/gcc/cc1" -quiet -nostdinc -std=gnu17 -O2 "${TCFG[@]}" "$f" -o "$OUT/$D/$b.s" \
      >> "$OUT/$D/cc1.log" 2>&1 || rc=1
  done
  t1=$(date +%s%N)
  echo "$((t1 - t0)) $rc"
}

# Warm-up, discarded.
rm -f "$OUT"/*/cc1.log
run_arm "$BA" "warm-a" > /dev/null
run_arm "$BB" "warm-b" > /dev/null

declare -a TA TB
fail=0
for i in $(seq 1 "$RUNS"); do
  ra=$(run_arm "$BA" "a"); rb=$(run_arm "$BB" "b")
  na=${ra% *}; ca=${ra#* }
  nb=${rb% *}; cb=${rb#* }
  [ "$ca" = 0 ] || { echo "run $i: arm A cc1 reported failure"; fail=1; }
  [ "$cb" = 0 ] || { echo "run $i: arm B cc1 reported failure"; fail=1; }
  TA+=("$na"); TB+=("$nb")
  printf 'run %2d   %-14s %8.3f s   %-14s %8.3f s   B/A %.4f\n' \
    "$i" "$LA" "$(echo "$na" | awk '{print $1/1e9}')" \
    "$LB" "$(echo "$nb" | awk '{print $1/1e9}')" \
    "$(echo "$na $nb" | awk '{print $2/$1}')"
done

# --- equal-work check -------------------------------------------------------
echo "--- output comparison (the two arms must be doing the same work)"
same=0; diffc=0; bad=0; bytes=0
for f in "${INPUTS[@]}"; do
  b=$(basename "$f" .i)
  a=$OUT/a/$b.s; c=$OUT/b/$b.s
  if [ ! -s "$a" ] || [ ! -s "$c" ] \
     || [ "$(wc -l < "$a")" -lt 20 ] || [ "$(wc -l < "$c")" -lt 20 ]; then
    echo "  UNSCORABLE $b (missing/short output)"; bad=$((bad+1)); continue
  fi
  bytes=$((bytes + $(wc -c < "$a")))
  if cmp -s "$a" "$c"; then same=$((same+1)); else
    diffc=$((diffc+1)); echo "  DIFFERS $b"
  fi
done
echo "  identical $same, differ $diffc, unscorable $bad, arm-A asm bytes $bytes"

# --- statistics -------------------------------------------------------------
stat () {   # stat <label> <values...>
  printf '%s' "$1 "; shift
  printf '%s\n' "$@" | sort -n | awk '
    {v[NR]=$1; s+=$1}
    END {n=NR; mean=s/n;
         med=(n%2)?v[(n+1)/2]:(v[n/2]+v[n/2+1])/2;
         for(i=1;i<=n;i++){d=v[i]-mean; ss+=d*d}
         sd=(n>1)?sqrt(ss/(n-1)):0;
         printf "min %.3f  median %.3f  mean %.3f  max %.3f  sd %.3f s (%.2f%%)\n",
                v[1]/1e9, med/1e9, mean/1e9, v[n]/1e9, sd/1e9, 100*sd/mean}'
}
echo "--- summary over $RUNS runs"
stat "$LA" "${TA[@]}"
stat "$LB" "${TB[@]}"
printf '%s\n' "${TA[@]}" | sort -n > "$OUT/ta.txt"
printf '%s\n' "${TB[@]}" | sort -n > "$OUT/tb.txt"
awk 'NR==FNR{a[FNR]=$1; na=FNR; next} {b[FNR]=$1; nb=FNR}
     END {
       amin=a[1]; bmin=b[1];
       amed=(na%2)?a[(na+1)/2]:(a[na/2]+a[na/2+1])/2;
       bmed=(nb%2)?b[(nb+1)/2]:(b[nb/2]+b[nb/2+1])/2;
       printf "ratio B/A  by min %.4f (%+.2f%%)   by median %.4f (%+.2f%%)\n",
              bmin/amin, 100*(bmin/amin-1), bmed/amed, 100*(bmed/amed-1);
       if ((bmin>amin) != (bmed>amed))
         print "NOTE: min and median disagree on the SIGN -- this run is not conclusive";
     }' "$OUT/ta.txt" "$OUT/tb.txt"

if [ "$diffc" -gt 0 ] || [ "$bad" -gt 0 ]; then
  echo "WARNING: the arms did not produce identical output, so the delta above"
  echo "         is NOT an overhead measurement.  Read it as two different"
  echo "         compilers doing two different amounts of work."
fi
[ "$fail" = 0 ] || echo "WARNING: at least one cc1 invocation failed; see $OUT/*/cc1.log"
