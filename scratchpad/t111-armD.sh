#!/bin/sh
# TASK #111, ARM D of the #68 sweep -- THE EXISTENCE-PREDICATE ARM.
#
# The hole this fills.  Arms B and C of #68 find *undefined symbols* (a link
# failure names them).  Arm A finds *divergent macro text* (two bases expand
# the same macro differently).  NONE of the three can see the case where:
#
#     back end P defines nothing,
#     back end Q defines macro X,
#     and SHARED code says `#ifdef X'.
#
# There is no undefined symbol (no code is emitted at all), and there is no
# divergent text (one side has no text).  The failure is an ABSENCE, and it
# surfaces arbitrarily far away -- for INIT_EXPANDERS, as a null dereference
# inside aarch64_set_current_function, in a back end that looks fine.
#
# WHAT THIS ARM DOES
#   1. D = every macro name `#define'd by any gcc/config/**/*.h back-end header.
#   2. C = every macro name tested with #ifdef / #ifndef / #if defined(...) in
#      SHARED code (gcc/*.cc, gcc/*.h, and the language front ends), i.e. every
#      translation unit that is NOT gcc/config/.
#   3. The population is D intersect C.
#   4. For each member: how many back ends define it, and does the base that
#      shared code is compiled against (i386) define it?  The ACTIONABLE subset
#      is `defined by >= 1 back end AND NOT defined by i386' -- those are the
#      ones where a back end silently loses a feature it has.
#   5. Subtract the FLOORED ones: if defaults.h (or another shared header)
#      defines the macro unconditionally, or under an #ifndef floor, then the
#      #ifdef in shared code is always true and there is nothing to lose.
#      Reporting those as actionable would be a false positive of exactly the
#      kind PRINCIPLES 4 rule 5 asks about.
#
# BLIND SPOTS -- stated, per PRINCIPLES 4 rule 5.
#   * `#if X' / `#if X > 0' (VALUE tests) are NOT in C.  Those are direction-1
#     value leaks and Arm A already sees them.  A macro used only that way is
#     invisible here.
#   * Macros `#define'd in a back end's .cc rather than its .h are not in D.
#   * A macro defined in a back-end header under its own #ifdef is counted as
#     defined; this arm does not evaluate conditions.  Upper bound, not exact.
#   * Text-level only: a `#ifdef X' inside an already-dead `#if 0' block counts.
#   * Only the FIRST-ORDER guard is seen.  If shared code is `#ifdef A' and A
#     is defined by everyone but expands to something only Q has, this arm is
#     silent -- that is the HAVE_V8HFmode shape, which is direction 1.
set -u
G=${G:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a583ac0157ff44074/gcc}
O=${O:-/tmp/t111-armD}
PRIMARY=${PRIMARY:-i386}
rm -rf "$O"; mkdir -p "$O"
[ -d "$G/config" ] || { echo "FATAL: no $G/config"; exit 9; }

# --- D: macro -> list of back ends defining it -------------------------------
# Back end = the directory directly under config/.  config/*.h at top level are
# SHARED-ish (elfos.h, dbxelf.h, ...) and are recorded as base `_common'.
find "$G/config" -name '*.h' -print \
| while read -r f; do
    rel=${f#"$G/config/"}
    case $rel in
      */*) be=${rel%%/*} ;;
      *)   be=_common ;;
    esac
    sed -n 's/^[ \t]*#[ \t]*define[ \t][ \t]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$f" \
    | while read -r m; do echo "$m $be"; done
  done | sort -u > "$O/defines.txt"
[ -s "$O/defines.txt" ] || { echo "FATAL: defines.txt empty -- extraction broke"; exit 9; }

# --- C: macros EXISTENCE-tested in shared code -------------------------------
# Shared = everything under gcc/ that is not config/ and not a generated build
# artefact.  Front ends included: they are compiled once for all back ends too.
find "$G" -name '*.cc' -o -name '*.h' -o -name '*.c' \
| grep -v "^$G/config/" | grep -v "^$G/testsuite/" \
| grep -v "^$G/ada/gcc-interface/" > "$O/shared-files.txt"
[ -s "$O/shared-files.txt" ] || { echo "FATAL: no shared files"; exit 9; }

# Three spellings, all of them existence predicates.
xargs -a "$O/shared-files.txt" grep -Hn -E \
  '^[ \t]*#[ \t]*(ifdef|ifndef)[ \t]+[A-Za-z_]|^[ \t]*#[ \t]*(if|elif).*defined' \
  > "$O/guards-raw.txt"
[ -s "$O/guards-raw.txt" ] || { echo "FATAL: no guards found"; exit 9; }

# name<TAB>file:line, one row per (macro, site).
awk -F: '
  { file=$1; line=$2; $1=""; $2=""; text=substr($0,3);
    if (match(text, /#[ \t]*ifdef[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
      s=substr(text,RSTART,RLENGTH); sub(/.*[ \t]/,"",s); print s "\t" file ":" line; }
    else if (match(text, /#[ \t]*ifndef[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
      s=substr(text,RSTART,RLENGTH); sub(/.*[ \t]/,"",s); print s "\t" file ":" line "\tNEG"; }
    else { t=text;
      while (match(t, /defined[ \t]*\(?[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
        s=substr(t,RSTART,RLENGTH); sub(/^defined[ \t]*\(?[ \t]*/,"",s);
        print s "\t" file ":" line; t=substr(t,RSTART+RLENGTH); } }
  }' "$O/guards-raw.txt" > "$O/guards.txt"

# --- intersect ---------------------------------------------------------------
cut -f1 "$O/guards.txt" | sort -u > "$O/guarded-names.txt"
awk '{print $1}' "$O/defines.txt" | sort -u > "$O/defined-names.txt"
comm -12 "$O/guarded-names.txt" "$O/defined-names.txt" > "$O/population.txt"

# --- shared-header floors ----------------------------------------------------
# A macro that defaults.h (or any shared header) defines is never absent, so
# the #ifdef cannot be false for a back end that has it.
find "$G" -maxdepth 1 -name '*.h' > "$O/sharedh.txt"
echo "$G/system.h" >> "$O/sharedh.txt"
xargs -a "$O/sharedh.txt" sed -n 's/^[ \t]*#[ \t]*define[ \t][ \t]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' \
  | sort -u > "$O/floored.txt"

# --- classify ----------------------------------------------------------------
: > "$O/report.txt"
while read -r m; do
  bes=$(awk -v m="$m" '$1==m && $2!="_common" {print $2}' "$O/defines.txt" | sort -u)
  n=$(echo "$bes" | grep -c . )
  [ -z "$bes" ] && n=0
  prim=NO
  echo "$bes" | grep -qx "$PRIMARY" && prim=YES
  common=NO
  awk -v m="$m" '$1==m && $2=="_common"' "$O/defines.txt" | grep -q . && common=YES
  fl=NO
  grep -qx "$m" "$O/floored.txt" && fl=YES
  sites=$(awk -F'\t' -v m="$m" '$1==m {print $2}' "$O/guards.txt" | tr '\n' ' ')
  printf '%s\tnbe=%s\tprimary=%s\tconfig_common=%s\tshared_floor=%s\tsites=%s\n' \
    "$m" "$n" "$prim" "$common" "$fl" "$sites" >> "$O/report.txt"
done < "$O/population.txt"

# ACTIONABLE: at least one back end has it, the primary does not, and no shared
# header floors it.  These are the ones where a back end loses code entirely.
awk -F'\t' '$2!="nbe=0" && $3=="primary=NO" && $5=="shared_floor=NO"' "$O/report.txt" \
  > "$O/actionable.txt"
# And the mirror: the primary has it, some back end does not -- the primary's
# ANSWER leaking, direction 1.
awk -F'\t' '$3=="primary=YES"' "$O/report.txt" > "$O/primary-has.txt"

echo "population (config-header macro, existence-tested in shared code): $(wc -l < "$O/population.txt")"
echo "  primary(i386) defines it:                                       $(wc -l < "$O/primary-has.txt")"
echo "  ACTIONABLE (>=1 back end has it, i386 does not, no shared floor): $(wc -l < "$O/actionable.txt")"
echo
echo "--- ACTIONABLE, by number of back ends defining ---"
sort -t= -k2 -rn "$O/actionable.txt" | awk -F'\t' '{printf "%-34s %-9s %s\n", $1, $2, $6}'
