#!/bin/sh
# THE scan-assembler BOARD: per target, per gcc.target/<dir>, and the failing
# patterns by name.
#
# WHY THIS SUBSET IS THE RIGHT ONE (user's ruling): a `scan-assembler' test
# needs no libgcc, no linker, no execution and NO ASSEMBLER.  It compiles to
# `.s' and greps the text.  Everything this build lacks is irrelevant to it,
# and what it asks -- "did the compiler emit the right instruction FOR THIS
# TARGET" -- is exactly the one-name-several-authorities defect class.
#
# It reads the merged .sum only; it measures nothing itself, so it is only as
# good as the run that produced them.  It REFUSES a target with no .rc stamp
# for the same reason mtscore.sh does: a log being written looks exactly like
# a log that finished.
set -u
B=${1:?build dir}; shift

for T in "$@"; do
  SUM="$B/gcc/testsuite.$T/gcc/gcc.sum"
  echo
  echo "################ $T"
  if [ ! -f "$B/check-$T.rc" ] || [ ! -f "$SUM" ]; then
    echo "  REFUSED: no finished run for $T"
    continue
  fi
  grep -q '=== gcc Summary' "$SUM" || { echo "  REFUSED: truncated .sum"; continue; }

  echo "-- gcc.target/<dir>: PASS FAIL XFAIL UNSUP UNRES ERROR   (compile-only run)"
  awk '
    /^(PASS|FAIL|XPASS|XFAIL|UNSUPPORTED|UNRESOLVED|ERROR): gcc\.target\// {
      v=$1; sub(":","",v); split($2,a,"/"); d=a[2];
      c[d";"v]++; seen[d]=1;
    }
    END {
      for (d in seen)
        printf "   %-12s %8d %8d %8d %8d %8d %8d\n", d,
          c[d";PASS"], c[d";FAIL"], c[d";XFAIL"],
          c[d";UNSUPPORTED"], c[d";UNRESOLVED"], c[d";ERROR"];
    }' "$SUM" | sort

  # WHAT KIND OF FAILURE, over the whole run.  A scan-assembler failure and a
  # "test for excess errors" failure are different findings: the first says the
  # compiler emitted the wrong instruction, the second that it refused the
  # input at all.  Counting them together produces a number with no cause.
  echo "-- FAIL kinds, whole run:"
  for k in 'scan-assembler' 'excess errors' 'internal compiler error' \
           'compilation failed' 'execution test'; do
    printf '   %-26s %s\n' "$k" "$(grep -c "^FAIL: .*$k" "$SUM" || true)"
  done

  echo "-- top scan-assembler failures (the PATTERN is the cause, not a count):"
  grep '^FAIL: .*scan-assembler' "$SUM" \
    | sed 's/^FAIL: //' \
    | awk '{ $1=""; print }' \
    | sort | uniq -c | sort -rn | head -15
done
