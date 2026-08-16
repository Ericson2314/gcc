#!/bin/sh
# For each of the 47 back ends: is there an EXECUTABLE `<triple>-as' anywhere in
# the tool dirs we can see, and does upstream have a `gcc.target/<be>' dir?
#
# Keyed on the CANONICAL triple spelling, which is the trap that cost a night:
# `astry2.sh' installed tools under SHORT triples that no build rule looks for,
# and a tool present under the wrong name is indistinguishable from absent --
# it falls back to the host assembler silently, three layers away.
#
# Searches every candidate dir given in TOOLDIRS so an assembler materialised by
# an earlier agent under a different path is not re-declared missing.
set -u
S=$(cd "$(dirname "$0")" && pwd)
MAP="$S/agent-acda89931a903ec27-backends.txt"
# TOOLDIRS may be given directly, or as a file listing one dir per line via
# TOOLDIRS_FILE -- the latter because the candidate set is ~33 dirs wide.
if [ -n "${TOOLDIRS_FILE:-}" ]; then
  TOOLDIRS=$(cat "$TOOLDIRS_FILE")
else
  TOOLDIRS=${TOOLDIRS:-/tmp/gasbin-agent-acda89931a903ec27}
fi

printf '%-12s %-30s %-4s %-9s %s\n' BACKEND TRIPLE EXP AS WHERE
nas=0; noas=0; noexp=0
for row in $(cat "$MAP"); do
  be=$(echo "$row" | cut -d: -f1)
  T=$(echo "$row"  | cut -d: -f2)
  ex=$(echo "$row" | cut -d: -f3)
  found=""
  for d in $TOOLDIRS; do
    if [ -x "$d/$T-as" ] && "$d/$T-as" --version 2>&1 | grep -q 'GNU assembler'; then
      found=$d; break
    fi
  done
  e=$([ -n "$ex" ] && echo yes || echo NO-EXP
      )
  [ -n "$ex" ] || noexp=$((noexp+1))
  if [ -n "$found" ]; then
    printf '%-12s %-30s %-4s %-9s %s\n' "$be" "$T" "$e" EXEC-OK "$found"
    nas=$((nas+1))
  else
    printf '%-12s %-30s %-4s %-9s %s\n' "$be" "$T" "$e" NO-AS -
    noas=$((noas+1))
  fi
done
echo
echo "AS-PRESENT=$nas  AS-MISSING=$noas  NO-EXP=$noexp  (of 47)"
