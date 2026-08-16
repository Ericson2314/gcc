#!/bin/sh
# Rank ICE causes by BREADTH and by VOLUME, with three corrections to
# `agent-acda89931a903ec27-causes.sh' -- each of which hid a shared cause.
#
# CORRECTION 1 -- A SELF-DESCRIBING DIAGNOSTIC NAMES THE BACK END, SO THE
# BREADTH RANKING CANNOT SEE IT.  This branch's best diagnostics say which back
# end they are about:
#
#     back end 'vax' has no pipeline automaton, but shared scheduling code
#     compiled for a primary that has one is asking it for pipeline hazards
#
# Six back ends emit that message and it is ONE defect in shared code -- but
# the text differs per back end, so ordering 1 scores it as six separate causes
# of one back end each and it never appears near the top.  The DFA-absent case
# is the single largest ICE cause on this board and the previous board recorded
# it as avr's alone.  A `%s' in a diagnostic is exactly what makes it useful to
# a human and invisible to a text-keyed ranking; the fix is to fold the quoted
# back-end name out before keying.
#
# CORRECTION 2 -- `s/[0-9][0-9]*/N/g' MANGLES BACK-END NAMES.  Digit-squashing
# is right for line numbers and wrong for identifiers: `xstormy16' becomes
# `xstormyN', `rl78' -> `rlN', `h8300' -> `hN'.  So even after correction 1 the
# names would not have matched each other.  Digits are squashed only after the
# quoted name has been removed.
#
# CORRECTION 3 -- THE BACK-END LIST IS BUILT WITH A REGEX MATCH.  causes.sh has
#
#     if (b[k] !~ $2) b[k] = b[k] " " $2
#
# which treats the back-end name as a REGEX and substring-matches an
# already-accumulated list, so a name that is a substring of the list is
# dropped while the counter still increments.  That is why its output shows
# `28' beside 27 listed back ends.  Same family as the `awk '$0 ~ f'' trap
# PRINCIPLES already records.  Keyed exact-match here.
#
# ICE-ONLY BY DESIGN, and the exclusion is stated rather than silent.  The
# generic `error:' channel on this subset is dominated by harness environment
# -- `C++ compiler not installed', `no include path in which to search for
# stdint.h', `ld returned 1 exit status' -- which is true of 28 back ends and
# says nothing about any of them: there is no target libc, no libstdc++ and no
# linker in a MT_COMPILE_ONLY run, by construction.  Ranking those first buries
# every real cause.  They are counted and reported as a bloc instead.
set -u
OUT=${OUT:?dir holding gcc-<be>.log}
P="$OUT/ice-pairs.txt"; : > "$P"
V="$OUT/ice-vol.txt";   : > "$V"

nlog=0
for f in "$OUT"/gcc-*.log; do
  [ -f "$f" ] || continue
  be=$(basename "$f" .log); be=${be#gcc-}
  nlog=$((nlog+1))
  # CORRECTION 4 -- THE SAME ICE IS LOGGED THREE TIMES, IN THREE ENCODINGS.
  # `gcc.log' carries each ICE as the compiler's own line (CR-terminated), as
  # the DejaGnu `FAIL:' record (parenthesised), and again in the re-run output.
  # Counting raw `internal compiler error:' hits therefore multiplies every
  # volume figure by three -- vax's DFA cause read 2898 and 1449 as two
  # separate rows for what is one number.  The `FAIL:' line is the authority:
  # exactly one per test RESULT, which is the quantity a board means by
  # "results".
  sed -n 's/^FAIL:.*(internal compiler error: \(.*\)/\1/p' "$f" \
    | sed "s/back end '[^']*'/back end 'BE'/g" \
    | sed 's/\r$//; s/)$//; s/[0-9][0-9]*/N/g; s/  */ /g; s/ *$//' \
    | sort > "$OUT/.ice-$be"
  sort -u "$OUT/.ice-$be" | while IFS= read -r c; do
    [ -n "$c" ] && printf '%s\t%s\n' "$be" "$c"
  done >> "$P"
  awk -v b="$be" 'NF{print}' "$OUT/.ice-$be" >> "$V"
  rm -f "$OUT/.ice-$be"
done

echo "=== logs read: $nlog   distinct (backend, ICE cause) pairs: $(wc -l < "$P")"
echo
echo "=== ORDERING 1: by NUMBER OF BACK ENDS sharing the ICE (breadth) ==="
awk -F'\t' '
  { n[$2]++; if (!seen[$2 SUBSEP $1]++) b[$2] = b[$2] " " $1 }
  END { for (c in n) printf "%3d\t%s\t%s\n", n[c], c, b[c] }' "$P" \
  | sort -rn | head -20 \
  | while IFS="$(printf '\t')" read -r n c bl; do
      printf '%3d  %s\n     backends:%s\n' "$n" "$c" "$bl"
    done

echo
echo "=== ORDERING 2: by TOTAL ICE OCCURRENCES (volume) ==="
sort "$V" | uniq -c | sort -rn | head -20

echo
echo "=== the excluded bloc, stated rather than dropped ==="
> "$OUT/.bloc"
for pat in 'C++ compiler not installed' 'no include path in which to search' \
           'ld returned' 'GCC is not configured to support'; do
  nbe=0; nres=0
  for f in "$OUT"/gcc-*.log; do
    [ -f "$f" ] || continue
    # log occurrences, not FAIL records: these arrive as compiler diagnostics
    # whose FAIL line reads only `Excess errors', so the text is not on the
    # FAIL line at all.  A bloc estimate, and labelled as one.
    n=$(grep -c "$pat" "$f")
    [ "$n" -gt 0 ] && { nbe=$((nbe+1)); nres=$((nres+n)); }
  done
  printf '%3d back ends  %8d results  %s\n' "$nbe" "$nres" "$pat" >> "$OUT/.bloc"
done
sort -rn "$OUT/.bloc"; rm -f "$OUT/.bloc"
echo "(no target libc, no libstdc++, no linker exist in a MT_COMPILE_ONLY run --"
echo " these are the harness's environment, not any back end's defect)"
