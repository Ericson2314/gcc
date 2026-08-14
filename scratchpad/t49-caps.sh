#!/bin/sh
# #49 -- re-verify the gas/as/ld capability conversions.
#
# THE FAILURE SHAPE THIS LOOKS FOR.  The conversion replaced `HAVE_AS_x' /
# `HAVE_GAS_x' / `HAVE_LD_x' compile-time macros with runtime `targ_caps'
# fields, and deleted the AC_DEFINE that used to supply them.  Any site still
# spelling the OLD name is now reading an UNDEFINED macro -- and per PRINCIPLES
# section 4, `#if FOO' on an undefined FOO does not error, it silently
# evaluates to FALSE.  So a conversion that missed a site does not fail to
# build; it silently turns a feature off, for whichever back ends still spell
# it.
#
# This is invisible on i386 + aarch64 whenever the site lives in some other
# back end's files, which is the whole reason #49 was unverifiable until 48
# back ends produced objects.
#
# NON-VACUITY FIRST (PRINCIPLES section 7): when every arm of a probe reads
# empty, that looks exactly like "no problem here".  Each population below is
# asserted non-empty BEFORE anything is scored.
#
# usage: t49-caps.sh <gcc-srcdir> [builddir]
set -e
G=${1:?gcc srcdir (the gcc/ directory)}
D=$2
G=$(cd "$G" && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' 0

echo "== srcdir $G"
[ -f "$G/target-caps.h" ] || { echo "FATAL: no target-caps.h; wrong tree"; exit 9; }

## (1) The names the conversion RETIRED.  Authority: the capability keys
## target-specs/configure emits, cross-checked against target-caps.h fields.
sed -n 's/^  *bool  *\([a-z0-9_]*\);.*/\1/p;s/^  *const char \*\([a-z0-9_]*\);.*/\1/p;s/^  *int  *\([a-z0-9_]*\);.*/\1/p' \
  "$G/target-caps.h" | sort -u > "$T/fields"
nf=$(wc -l < "$T/fields")
[ "$nf" -gt 20 ] || { echo "FATAL: only $nf target_caps fields parsed; the parser is wrong, not the tree"; exit 9; }
echo "== target_caps fields: $nf"

## (2) Every HAVE_{AS,GAS,LD}_* name still SPELLED anywhere under gcc/.
grep -rhoE 'HAVE_(GAS|AS|LD)_[A-Z0-9_]+' \
  --include='*.cc' --include='*.h' --include='*.c' --include='*.md' "$G" \
  | sort -u > "$T/spelled"
ns=$(wc -l < "$T/spelled")
[ "$ns" -gt 50 ] || { echo "FATAL: only $ns HAVE_* names found; the grep is wrong"; exit 9; }
echo "== HAVE_{AS,GAS,LD}_* names spelled in sources: $ns"

## (3) Every such name a build can still DEFINE.  Authority: config.in and
## auto-host.h -- the generated artefact, not the .ac, per PRINCIPLES section 7
## ("search the generated artefact").
: > "$T/defined"
for f in "$G/config.in" "$G/auto-host.h" "$D/gcc/auto-host.h" "$D/gcc/config.h"; do
  [ -f "$f" ] || continue
  echo "   reading $f"
  # `|| true': a no-match grep exits 1, and under `set -e' that aborted the
  # scan silently after the first file -- which read as "nothing more to find".
  grep -hoE 'HAVE_(GAS|AS|LD)_[A-Z0-9_]+' "$f" >> "$T/defined" || true
done
sort -u "$T/defined" -o "$T/defined"
nd=$(wc -l < "$T/defined")
echo "== HAVE_{AS,GAS,LD}_* names a build can still define: $nd"
if [ "$nd" = 0 ]; then
  echo "   (zero: gcc/configure.ac probes no assembler at all -- gcc_GAS_CHECK_FEATURE"
  echo "    went 51 -> 0.  Then EVERY spelled name below is undefined.)"
fi

## (4) THE POPULATION: spelled but undefinable -> silently FALSE.
comm -23 "$T/spelled" "$T/defined" > "$T/silent"
nsil=$(wc -l < "$T/silent")
echo
echo "== SILENTLY-FALSE NAMES: $nsil"

## (5) Attribute each to the back ends that spell it, and split by whether the
## site is a PREPROCESSOR CONDITIONAL (silently false, behaviour change) or
## merely a mention in a comment/string (harmless).  A count of occurrences
## would not distinguish those, and per PRINCIPLES a count is the weakest
## evidence available.
echo
printf '%-46s %-6s %s\n' NAME "#if?" "BACK ENDS SPELLING IT ON A CONDITIONAL"
while read -r n; do
  [ -n "$n" ] || continue
  # conditional sites only: #if/#ifdef/#elif/defined()
  grep -rlE "^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef|elif).*\<$n\>" \
    --include='*.cc' --include='*.h' --include='*.c' --include='*.md' "$G" \
    > "$T/hits" 2>/dev/null || true
  [ -s "$T/hits" ] || continue
  bes=$(sed "s|^$G/||" "$T/hits" | sed -n 's|^config/\([^/]*\)/.*|\1|p' | sort -u | tr '\n' ' ')
  top=$(sed "s|^$G/||" "$T/hits" | grep -v '^config/' | tr '\n' ' ')
  printf '%-46s %-6s %s%s\n' "$n" "$(wc -l < "$T/hits")" "$bes" "${top:+[shared: $top]}"
done < "$T/silent"
