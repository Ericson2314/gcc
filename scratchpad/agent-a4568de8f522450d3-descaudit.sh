#!/bin/sh
# agent-a4568de8f522450d3-descaudit.sh -- WHICH `DESCRIPTOR' macros are still
# spelled raw in shared code?
#
# THE DEFECT.  `-leakcensus.sh' subtracts two buckets from the documented macro
# list before reporting a leak population:
#
#   REDIRECT    an `#undef'/`#define' pair in multi-target-macros.h.  The name
#               IS still spelled at the call site -- that is how a redirect
#               works -- so "still spelled" says nothing about it.
#   DESCRIPTOR  the name appears anywhere in a `target-*.h' conversion header.
#
# The census's own comment calls DESCRIPTOR "weaker -- those headers also
# DISCUSS macros they have not converted".  It is weaker than that: a
# DESCRIPTOR macro is claimed converted BY CALL-SITE REWRITE, so if the name is
# still spelled in shared code the conversion did not happen and the macro is
# still a leak -- but it has been subtracted from the leak count.
#
# Measured instance that motivated this, and it is board item #3 rather than a
# hypothetical: ASM_OUTPUT_MAX_SKIP_ALIGN scores DESCRIPTOR on the strength of
# ONE MENTION in `target-caps.h:314', which is a sentence about it.  The macro
# is spelled raw at `varasm.cc:2173,2181,2182,2184' and `final.cc:2432,2436,
# 2438', all `#ifdef'-guarded, all answered by i386.
#
# So the 296 headline is NOT a pure upper bound: DESCRIPTOR removes real leaks
# from it.  This script says how many.
#
# WHAT THIS CANNOT DO: it cannot bless a macro.  A name absent from shared code
# is consistent with a real conversion and also with a macro shared code never
# spelled in the first place.  It can only REVOKE a DESCRIPTOR claim, so it is
# deliberately over-eager -- PRINCIPLES' "when an instrument can only take
# away, make it too eager; when it can grant, make it exact."
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
O=${O:-/tmp/w-a4568de8f522450d3}/desc
CONV=${CONV:?set CONV to the leakcensus report.conv}
mkdir -p "$O"
cd "$W/gcc"

[ -f "$CONV" ] || { echo "FATAL: no $CONV"; exit 9; }
awk -F'\t' '$1=="DESCRIPTOR"{print $4}' "$CONV" | sort -u > "$O/desc.names"
N=$(wc -l < "$O/desc.names")
[ "$N" -gt 10 ] || { echo "FATAL: only $N DESCRIPTOR names; wrong input file"; exit 9; }
echo "DESCRIPTOR macros claimed converted: $N"

# SHARED CODE, AND GETTING THIS POPULATION RIGHT IS THE WHOLE SCAN.
#
# "Shared" here means: compiled ONCE, against the shared `tm.h', so a target
# macro spelled in it is answered by the primary.  That excludes three groups,
# and leaving any of them in produces false positives that look exactly like
# unconverted macros:
#
#   target-*.h            the conversion DESCRIPTORS.  They name every macro
#                         they convert, by construction.
#   target-*.cc           the conversion MACHINERY.  `target-cumargs.cc' is
#                         compiled ONCE PER BASE with `BASE_HEADER (tm.h)', so
#                         `#ifdef PROMOTE_MODE / PROMOTE_MODE (m, u, type)' in
#                         it is the conversion WORKING, not a leak.  The
#                         `-select.cc' half spells macro names in its
#                         `internal_error' strings for the same reason.
#   defaults.h,           where a REDIRECT legitimately spells the name.
#   multi-target-macros.h
#
# Measured: leaving `target-*.cc' in scored ASM_DECLARE_FUNCTION_NAME,
# ASM_OUTPUT_FUNCTION_LABEL, PROMOTE_MODE and REG_ALLOC_ORDER -- four macros
# this branch is KNOWN to have converted, three of them last night -- as still
# leaking, and took the headline from 41 to 73.  Those four are the control
# set: the scan is not trustworthy while it flags them.
ls *.cc *.h 2>/dev/null \
  | grep -v '^target-.*\.h$' | grep -v '^target-.*\.cc$' \
  | grep -v '^defaults\.h$' | grep -v '^multi-target-' > "$O/shared.files"
echo "shared files scanned: $(wc -l < "$O/shared.files")"

# COMMENTS MUST BE STRIPPED PROPERLY, AND THE FIRST VERSION OF THIS SCRIPT DID
# NOT.  It skipped lines whose FIRST non-blank character is `/*', `*' or `//'.
# The conversion notes on this branch are multi-line `/* ... */' blocks whose
# continuation lines begin with ordinary prose, so every such line scored as
# code and the answer came out `80 of 94' -- including ASM_DECLARE_FUNCTION_NAME,
# which is converted and whose three "raw spellings" are all sentences in the
# comment explaining that it was converted.
#
# That is the same shape the audit is about: a text scan that cannot tell a
# mention from a use, one level up.  So the comment text is removed by a real
# state machine before anything is counted.
mkdir -p "$O/stripped"
while read -r f; do
  awk '
    { line = ""
      i = 1
      while (i <= length($0)) {
        c = substr($0, i, 2)
        if (incomment) {
          if (c == "*/") { incomment = 0; i += 2 } else i++
        } else if (c == "/*") { incomment = 1; i += 2 }
        else if (c == "//") { break }
        else { line = line substr($0, i, 1); i++ }
      }
      print line
    }' "$f" > "$O/stripped/$(echo "$f" | tr / _)"
done < "$O/shared.files"

: > "$O/suspect"
while read -r m; do
  # A raw spelling in CODE.  Comments are gone by construction now.
  hits=$(grep -nw "$m" "$O"/stripped/* 2>/dev/null)
  [ -n "$hits" ] || continue
  n=$(printf '%s\n' "$hits" | wc -l)
  printf '%s\t%s\n' "$n" "$m" >> "$O/suspect"
  printf '\n== %s -- %s raw spellings in shared code\n' "$m" "$n"
  printf '%s\n' "$hits" | head -6 | sed 's/^/   /'
done < "$O/desc.names"

echo
echo "=================================================================="
S=$(wc -l < "$O/suspect" 2>/dev/null || echo 0)
echo "DESCRIPTOR macros STILL SPELLED RAW in shared code: $S of $N"
echo "  -- each is a leak the census subtracted from its own headline."
sort -k1,1nr "$O/suspect" | awk -F'\t' '{printf "  %4s  %s\n",$1,$2}'

# NON-VACUITY.  ASM_OUTPUT_MAX_SKIP_ALIGN is spelled raw at seven sites in
# varasm.cc and final.cc; if this scan cannot see it, the scan is broken and
# every zero it reports is meaningless.  This is an arm on the INSTRUMENT, not
# a claim about the tree: the day that macro is genuinely converted this must
# be re-pointed, and it says so rather than being silently deleted.
echo
echo "NON-VACUITY (an arm on the scanner, not on the tree):"
rc=0
if grep -qw ASM_OUTPUT_MAX_SKIP_ALIGN "$O/suspect" 2>/dev/null; then
  echo "  ok  POSITIVE: ASM_OUTPUT_MAX_SKIP_ALIGN seen as raw-spelled, as it is"
else
  echo "  FATAL: the scanner cannot see a macro known to be raw-spelled at"
  echo "         varasm.cc:2173 and final.cc:2432 -- every zero here is void"
  rc=9
fi

# THE NEGATIVE CONTROL, WHICH IS THE ARM THAT ACTUALLY COST SOMETHING.  A scan
# that flags everything has a perfect positive arm and is worthless.  These
# four are converted -- three of them on this board last night -- so a scan
# that reports them is over-eager and its headline is not a count of anything.
# Both directions, per PRINCIPLES: a check that cannot fail is not a check.
for m in ASM_DECLARE_FUNCTION_NAME ASM_OUTPUT_FUNCTION_LABEL PROMOTE_MODE \
         REG_ALLOC_ORDER; do
  if grep -qw "$m" "$O/suspect" 2>/dev/null; then
    echo "  FATAL NEGATIVE: $m is CONVERTED and the scan flagged it;"
    echo "         the population in \$O/shared.files is wrong"
    rc=9
  else
    echo "  ok  NEGATIVE: $m converted and not flagged"
  fi
done
[ $rc -eq 0 ] || exit 9
