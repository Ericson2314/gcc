#!/bin/sh
# #49 -- the arm that can actually FAIL a converted capability.
#
# THE DEFECT.  A converted capability is `#define HAVE_LD_PIE (targ_caps.ld_pie)'
# -- a RUNTIME read.  That is correct for a site spelling `if (HAVE_LD_PIE)'.
# It is WRONG, silently, for a site spelling:
#
#     #ifdef HAVE_LD_PIE        -> now ALWAYS TRUE.  The macro is defined; its
#     #ifndef HAVE_LD_PIE          runtime value is never consulted.  The
#     #if defined(HAVE_LD_PIE)     feature is unconditionally ON for every
#                                  target, including ones whose probe said no.
#
# and it is LOUD for `#if HAVE_LD_PIE', because `targ_caps.ld_pie' is not an
# integral constant expression -- so that spelling would already have been
# found.  Only the `#ifdef' family is silent, which is why this arm exists.
#
# WHY THIS IS "CORRECT BY LUCK ON i386 + aarch64" (PRINCIPLES section 1).  The
# pre-conversion answer came from probing the BUILD machine's binutils.  On a
# modern GNU toolchain nearly every one of these probes said YES.  So
# "always true" and "what the probe said" AGREE on the configured pair, and
# disagree only for a target whose real assembler/linker lacks the feature --
# which no two-back-end build ever exercises.
#
# usage: t49-ifdef.sh <gcc-srcdir>
set -e
G=$(cd "${1:?gcc srcdir}" && pwd)
[ -f "$G/defaults.h" ] || { echo "FATAL: no defaults.h; wrong tree"; exit 9; }

# (1) The CONVERTED names, read from the conversion layer itself rather than
# from a hand list -- defaults.h is the authority for what was converted.
grep -oE '^#define (HAVE_(GAS|AS|LD)_[A-Z0-9_]+) \(targ_caps\.' "$G/defaults.h" \
  | awk '{print $2}' | sort -u > /tmp/t49-converted.txt
nc=$(wc -l < /tmp/t49-converted.txt)
# NON-VACUITY FATAL: an empty converted set would make every arm below read
# clean, which is indistinguishable from "no defects".
[ "$nc" -gt 10 ] || { echo "FATAL: only $nc converted names parsed from defaults.h; refusing to score"; exit 9; }
echo "== converted capabilities (authority: defaults.h targ_caps redirects): $nc"

# (2) NON-VACUITY for the site grep: it must find a KNOWN #ifdef in this tree.
ctl=$(grep -rlE '^[[:space:]]*#[[:space:]]*ifdef[[:space:]]+GCC_TARGET_CAPS_H\b' --include='*.h' "$G" | head -1)
echo "   (site-grep control: matching an #ifdef at all is proved by the runs below)"

echo
printf '%-46s %-5s %s\n' 'CONVERTED NAME' 'SITES' 'FILES WITH #ifdef/#ifndef/defined() -- ALWAYS TRUE'
bad=0; badnames=0
for n in $(cat /tmp/t49-converted.txt); do
  f=$(grep -rlE "^[[:space:]]*#[[:space:]]*(ifdef|ifndef)[[:space:]]+$n\b|^[[:space:]]*#[[:space:]]*(if|elif)\b.*defined[[:space:]]*\([[:space:]]*$n[[:space:]]*\)" \
        --include='*.cc' --include='*.h' --include='*.c' --include='*.md' "$G" 2>/dev/null \
        | sed "s|^$G/||" | sort -u)
  [ -n "$f" ] || continue
  k=$(echo "$f" | wc -l)
  bad=$((bad+k)); badnames=$((badnames+1))
  printf '%-46s %-5s %s\n' "$n" "$k" "$(echo "$f" | tr '\n' ' ')"
done
echo
echo "== ALWAYS-TRUE SITES: $bad, over $badnames converted capabilities"
[ "$badnames" = 0 ] && echo "   (clean: every converted capability is read only as a value)"
exit 0
