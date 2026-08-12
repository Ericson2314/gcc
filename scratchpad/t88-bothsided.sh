#!/usr/bin/env bash
# BOTH-SIDED evidence for one option that only ONE of the two configured back
# ends really declares.
#
# Showing that the owner still gets its own answer proves nothing on its own;
# the failure mode this change exists to prevent is a placeholder acquiring a
# value, and the failure mode it must not introduce is the owner losing one.
# So both are asserted, on the same option, from the two per-base tables --
# which are the DATA, selected at run time -- and from the shared struct, which
# is the LAYOUT.
#
#   t88-bothsided.sh <builddir>/gcc <owner-base> <other-base> <option> <member>
set -u -o pipefail
D=${1:?}; OWN=${2:?}; OTH=${3:?}; OPT=${4:?}; MEM=${5:?}
case $D in /*) ;; *) echo "FATAL: builddir must be absolute"; exit 9;; esac
A=$D/mt-$OWN/options-tables.cc
B=$D/mt-$OTH/options-tables.cc
for f in "$A" "$B" "$D/options.h" "$D/options-$OWN.h" "$D/options-$OTH.h"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done
rc=0
echo "option '-$OPT', really declared by $OWN, stubbed in $OTH; member x_$MEM"
echo

# The cl_options[] entry is 12 lines or so; take the block from the name to the
# closing brace of that element.
entry () { awk -v o="\"-$1\"," '
  index($0,o){f=1}
  f{print}
  f && /},?$/{exit}' "$2"; }

for side in OWNER OTHER; do
  [ $side = OWNER ] && { f=$A; b=$OWN; } || { f=$B; b=$OTH; }
  entry "$OPT" "$f" > /tmp/t88-bs-$b.txt
  n=$(wc -l < /tmp/t88-bs-$b.txt)
  echo "--- $side ($b), $n lines of cl_options[] entry"
  [ "$n" -ge 5 ] || { echo "  FATAL: no entry extracted for -$OPT from $f; nothing is being compared"; exit 9; }
  sed 's/^/    /' /tmp/t88-bs-$b.txt
done
echo

# The owner drives real state: a byte offset into gcc_options and a non-zero
# CL_ mask.  The stub drives nothing: `(unsigned short) -1' for flag_var is
# opt-functions.awk var_ref() answer for "no variable at all".
if grep -q "offsetof (struct gcc_options, x_$MEM)" /tmp/t88-bs-$OWN.txt; then
  echo "PASS  $OWN entry writes through offsetof (struct gcc_options, x_$MEM)"
else
  echo "FAIL  $OWN entry has no offsetof for x_$MEM -- the owner lost its state"; rc=1
fi
if grep -q '(unsigned short) -1' /tmp/t88-bs-$OTH.txt; then
  echo "PASS  $OTH entry has flag_var (unsigned short) -1 -- the placeholder writes nowhere"
else
  echo "FAIL  $OTH entry names a variable; the placeholder acquired state"; rc=1
fi
if grep -qE '^ *CL_[A-Z_]' /tmp/t88-bs-$OWN.txt; then
  echo "PASS  $OWN entry carries a CL_ mask, so the option is reachable there"
else
  echo "FAIL  $OWN entry has no CL_ mask"; rc=1
fi
if grep -qE '^ *CL_UNDOCUMENTED,$' /tmp/t88-bs-$OTH.txt; then
  echo "PASS  $OTH entry is CL_UNDOCUMENTED alone -- no CL_TARGET, so find_opt does not match it"
else
  echo "FAIL  $OTH entry has a mask other than CL_UNDOCUMENTED:"; grep -E '^ *CL_' /tmp/t88-bs-$OTH.txt; rc=1
fi

echo
echo "--- the LAYOUT is shared, and identical in all three headers"
for h in options.h options-$OWN.h options-$OTH.h; do
  l=$(grep -n "x_$MEM;" "$D/$h" | head -1)
  [ -n "$l" ] || { echo "FAIL  $h has no x_$MEM"; rc=1; continue; }
  echo "  $h: $l"
done
u=$(grep -h "x_$MEM;" "$D/options.h" "$D/options-$OWN.h" "$D/options-$OTH.h" | sort -u | wc -l)
[ "$u" -eq 1 ] && echo "PASS  one declaration text across the three headers" \
               || { echo "FAIL  $u different declarations of x_$MEM"; rc=1; }
echo "OVERALL rc=$rc"
exit $rc
