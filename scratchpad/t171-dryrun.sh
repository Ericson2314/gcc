#!/bin/sh
# #171 -- run the two new generators against the SOURCE tree, with no build
# dir, so that a syntax or logic error in either shows up in seconds instead of
# twenty minutes into a make.  Three bases, chosen because aarch64 and arm both
# contribute a pass_insert_bti and i386 contributes a NEXT_PASS_WITH_ARG pass.
set -u
G=${1:?gcc source dir}
G=$(cd "$G" && pwd)
O=${2:-/tmp/t171-dry}
rm -rf "$O"; mkdir -p "$O"
TAGS="$G/config/i386/i386-passes.def=i386 $G/config/aarch64/aarch64-passes.def=aarch64 $G/config/arm/arm-passes.def=arm"

awk -f "$G/gen-pass-instances.awk" -v pass_bases="$TAGS" \
  "$G/passes.def" "$G/config/i386/i386-passes.def" \
  "$G/config/aarch64/aarch64-passes.def" "$G/config/arm/arm-passes.def" \
  > "$O/pass-instances.def" 2> "$O/pi.err"
echo "gen-pass-instances rc=$?  lines=$(wc -l < "$O/pass-instances.def")"
cat "$O/pi.err"
echo "-- target-pass NEXT_PASS lines:"
grep -nE 'NEXT_PASS[A-Z_]* \(pass_[A-Za-z0-9_]*_mt_' "$O/pass-instances.def"

echo
echo "-- NEGATIVE CONTROL: the same run with the tags REMOVED must be refused."
awk -f "$G/gen-pass-instances.awk" \
  "$G/passes.def" "$G/config/aarch64/aarch64-passes.def" \
  > "$O/untagged.def" 2> "$O/untagged.err"
echo "  rc=$?  (want non-zero)  output lines=$(wc -l < "$O/untagged.def") (want 0)"
cat "$O/untagged.err"

echo
echo "-- header:"
awk -f "$G/gen-target-passes.awk" -v mode=header -v pass_bases="$TAGS" \
  > "$O/multi-target-passes.h" 2> "$O/h.err"
echo "  rc=$?"; cat "$O/h.err"; cat "$O/multi-target-passes.h"

for b in i386 aarch64 arm; do
  echo
  echo "-- source for $b:"
  awk -f "$G/gen-target-passes.awk" -v mode=source -v want_base=$b \
    -v pass_bases="$TAGS" > "$O/target-passes-$b.cc" 2> "$O/$b.err"
  echo "  rc=$?"; cat "$O/$b.err"
  grep -n '^make_\|^opt_pass\|mt_base' "$O/target-passes-$b.cc"
done

echo
echo "-- CROSS-CHECK: every make_*_mt_* called by pass-instances.def must be"
echo "   declared in the header and defined in exactly one source."
awk 'match($0, /pass_[A-Za-z0-9_]*_mt_[A-Za-z0-9_]*/) {
       print substr($0, RSTART, RLENGTH) }' "$O/pass-instances.def" \
  | sort -u > "$O/called"
grep -o 'make_pass_[A-Za-z0-9_]*' "$O/multi-target-passes.h" \
  | sed 's/^make_//' | sort -u > "$O/declared"
cat "$O"/target-passes-*.cc | grep -o '^make_pass_[A-Za-z0-9_]*' \
  | sed 's/^make_//' | sort > "$O/defined-all"
sort -u "$O/defined-all" > "$O/defined"
echo "  called=$(wc -l < "$O/called") declared=$(wc -l < "$O/declared") defined=$(wc -l < "$O/defined") defined-with-dups=$(wc -l < "$O/defined-all")"
echo "  called but not declared:"; comm -23 "$O/called" "$O/declared" | sed 's/^/    /'
echo "  called but not defined:";  comm -23 "$O/called" "$O/defined"  | sed 's/^/    /'
echo "  declared but never called:"; comm -13 "$O/called" "$O/declared" | sed 's/^/    /'
[ "$(wc -l < "$O/defined-all")" = "$(wc -l < "$O/defined")" ] \
  || echo "  FATAL: a forwarder is defined twice"
