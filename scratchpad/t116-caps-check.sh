#!/bin/sh
# t116: run check-target-caps.sh over a config file carrying EVERY key
# target-specs/configure.ac can emit, so the read arm is exercised on the new
# as_ltoffx_ldxmov_relocs rather than on whatever a partial build happened to
# write.
#
# METHOD RULE 7.  A green from this script means nothing unless the script can
# go red, so it runs THREE arms:
#   1. real       -- must PASS.
#   2. fault-A    -- the new key REMOVED from target-caps.h (its field deleted).
#                    Must FAIL, and must name the key.  This is the exact fault
#                    that was in the tree an hour ago.
#   3. fault-B    -- a bogus key added to the config file.  Must FAIL.
# If a fault arm passes, the checker is not enforcing and this script says so.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' 0

# Reproduce emit_keys: `name value' lines inside heredocs onto $target_config_file.
emit_keys () {
  awk '
    /^[ \t]*cat[ \t]*>>?[ \t]*"?\$\{?target_config_file\}?"?[ \t]*<</ {
      d = $0; sub(/.*<<[ \t]*/, "", d); gsub(/[^A-Za-z_0-9]/, "", d)
      inh = 1; delim = d; next }
    inh && $0 == delim { inh = 0; next }
    inh && /^[a-z_][a-z_0-9]*[ \t]/ { print $1 }
  ' "$1" | sort -u
}

emit_keys "$ROOT/target-specs/configure.ac" | sed 's/$/ 1/' > "$W/cfg"

# Non-vacuity: the config file must be non-empty and must contain the subject.
if ! test -s "$W/cfg"; then
  echo "FATAL: synthesised config file is empty; every key would read as dead" >&2
  exit 1
fi
if ! grep -qx 'as_ltoffx_ldxmov_relocs 1' "$W/cfg"; then
  echo "FATAL: the subject key is not emitted, so this run would not test it" >&2
  exit 1
fi
echo "config file: $(wc -l < "$W/cfg" | tr -d ' ') keys, subject present"

run () {   # $1 = srcdir  -> prints PASS/FAIL
  if sh "$1/check-target-caps.sh" "$1" "$W/cfg" > "$W/o" 2> "$W/e"; then
    echo PASS
  else
    echo FAIL
  fi
}

echo
echo "--- arm 1: real tree (must PASS)"
r1=$(run "$ROOT/gcc"); echo "  $r1"
test "$r1" = PASS || sed 's/^/  /' "$W/e"

echo
echo "--- arm 2: field deleted from target-caps.h (must FAIL naming the key)"
# The checker resolves its emitter as $srcdir/../target-specs/configure.ac, so
# the copy needs a sibling target-specs or it dies with "no emitter" -- a FAIL
# for a reason that has nothing to do with the injected fault.  That is exactly
# what the first version of this script did, and it scored as a passing fault
# arm.  A fault arm that fails for the wrong reason is a false red and is worth
# no more than a false green.
mkdir -p "$W/inj/gcc" "$W/inj/target-specs"
cp "$ROOT/target-specs/configure.ac" "$W/inj/target-specs/configure.ac"
cp -r "$ROOT/gcc/." "$W/inj/gcc/"
grep -v 'bool as_ltoffx_ldxmov_relocs;' "$ROOT/gcc/target-caps.h" \
  > "$W/inj/gcc/target-caps.h"
# Assert the injection actually removed something.
if cmp -s "$ROOT/gcc/target-caps.h" "$W/inj/gcc/target-caps.h"; then
  echo "FATAL: the injection changed nothing; the fault arm would test nothing" >&2
  exit 1
fi
r2=$(run "$W/inj/gcc"); echo "  $r2"
if grep -q as_ltoffx_ldxmov_relocs "$W/e"; then
  named2=yes
else
  named2=NO
fi
echo "  names the key: $named2"
echo "  diagnostic:"
sed 's/^/    /' "$W/e" | head -6

echo
echo "--- arm 3: bogus key in the config file (must FAIL)"
cp "$W/cfg" "$W/cfg.bak"
echo 'zzz_bogus_never_read 1' >> "$W/cfg"
r3=$(run "$ROOT/gcc"); echo "  $r3"
cp "$W/cfg.bak" "$W/cfg"

echo
echo "VERDICT: real=$r1 (want PASS)  field-deleted=$r2 (want FAIL)  bogus-key=$r3 (want FAIL)"
if [ "$r1" = PASS ] && [ "$r2" = FAIL ] && [ "$r3" = FAIL ] \
   && [ "$named2" = yes ]; then
  echo "OK -- the check passes and both injected faults fire, and the"
  echo "field-deleted arm fails BY NAME rather than for some other reason."
else
  echo "NOT OK -- an arm did not behave as required (named2=$named2)."
  exit 1
fi
