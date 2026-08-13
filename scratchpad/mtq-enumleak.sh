#!/bin/sh
# ENUMERATOR LEAK from the `HeaderInclude' (`I' record) option headers, and
# what it collides with.
#
# Sibling of mtO-optsmacro2.sh / mtO-allI.sh, which swept the MACROS those
# headers contribute.  This sweeps the other half: the ENUMERATORS.  Both
# halves leak for the same reason -- every generated options-<base>.h includes
# all 35 `I' headers, because the shared `gcc_options' struct has a member of
# every back end's option types -- but only the macro half can be `#undef'ed,
# so the macro fix (f3a75a98014) leaves this one entirely open.
#
# Two collision partners are scored, because they fail differently:
#
#   ATTR   an enumerator of the same name in a per-back-end
#          insn-attr-common-<cpu>.h (genattr-common's `enum attr_<name>').
#          LOUD: the two declarations meet in every TU of that back end.
#   IHDR   an enumerator of the same name in ANOTHER `I' header.  Also loud,
#          and it fires for every back end at once.
#
# Read from the BUILD DIRECTORY for the attr side, which is legitimate here
# only because this build configures all 48 back ends, so every back end's
# insn-attr-common-<cpu>.h exists.  The `I' side is read from the SOURCE.
#
# NON-VACUITY: refuses to score if either side came back empty.  An empty read
# is indistinguishable from "nothing collides", which is the answer this is
# trying to disprove.
#
# BLIND SPOTS AND KNOWN FALSE POSITIVES, stated rather than left to be
# rediscovered:
#
#  * the enumerator reader is a line matcher, not a parser, so a MACRO
#    PARAMETER spelled in caps on its own line scores as an enumerator.  The
#    one such hit today is `ENUM_VALUE', reported under IHDR from
#    config/c6x/c6x-opts.h and config/m68k/m68k-opts.h, where it is the second
#    parameter of C6X_ISA / M68K_DEVICE.  It is not a declaration and does not
#    collide.  Left over-broad deliberately: this instrument can only ever add
#    a suspect, never clear one.
#  * the transitive walk is ONE level.  A second level would be found only by
#    running it; the closure is recomputed each run, so widening it is a
#    one-line change if a case appears.
#  * it compares enumerator NAMES only.  An `I' header's enum TYPE name
#    colliding with a back end's type is a different arm and is not scored.
#
# usage: mtq-enumleak.sh <builddir>/gcc
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/../gcc" && pwd)
D=${1:?builddir/gcc}
[ -d "$D" ] || { echo "FATAL: $D is not a directory"; exit 9; }

T=$(mktemp -d)
trap 'rm -rf "$T"' 0

# The `I' headers, from every .opt file, exactly as opt-read.awk sees them,
# PLUS what they include.  The transitive step is not optional and the reason
# is the case that motivated this script: `TUNE_GENERIC' is declared in
# config/loongarch/loongarch-def.h, which is not an `I' header -- it is
# included BY loongarch-opts.h, which is.  A sweep reading only the `I' files
# scores loongarch as contributing no enumerator at all, i.e. it reports the
# reassuring answer.  One level is enough for the present tree and the closure
# is recomputed each run rather than listed.
awk '/^HeaderInclude$/ { getline h; print h }' "$SRC"/config/*/*.opt \
  | sort -u > "$T/ihdrs0"
n_i0=$(wc -l < "$T/ihdrs0")
[ "$n_i0" -gt 0 ] || { echo "FATAL: no HeaderInclude headers found"; exit 9; }
cp "$T/ihdrs0" "$T/ihdrs"
while read -r h; do
  [ -f "$SRC/$h" ] || { echo "FATAL: cannot open $SRC/$h"; exit 9; }
  d=$(dirname "$h")
  sed -n 's/^[ \t]*#[ \t]*include[ \t]*"\([^"]*\)".*/\1/p' "$SRC/$h" \
  | while read -r inc; do
      case "$inc" in
        */*) [ -f "$SRC/$inc" ] && echo "$inc" ;;
        *)   [ -f "$SRC/$d/$inc" ] && echo "$d/$inc" ;;
      esac
    done >> "$T/ihdrs" || true
done < "$T/ihdrs0"
sort -u "$T/ihdrs" -o "$T/ihdrs"
n_i=$(wc -l < "$T/ihdrs")
echo "HeaderInclude files: $n_i0   with one level of their own includes: $n_i"

# Enumerators declared by each `I' header.  Deliberately crude and OVER-BROAD:
# this instrument can only ever ADD a suspect, never clear one, so per
# PRINCIPLES 4 it is made too eager.  Anything of the form `NAME' or
# `NAME = ...' on its own line inside the file, all-caps-or-underscore, is
# taken as an enumerator.
: > "$T/ienum"
while read -r h; do
  [ -f "$SRC/$h" ] || { echo "FATAL: cannot open $SRC/$h"; exit 9; }
  awk -v h="$h" '
    /^[ \t]*[A-Z_][A-Za-z_0-9]*[ \t]*(=[^;]*)?,?[ \t]*$/ {
      s = $0
      sub(/^[ \t]*/, "", s); sub(/[ \t]*(=.*)?,?[ \t]*$/, "", s)
      if (s ~ /^[A-Z_][A-Za-z_0-9]*$/) print s, h
    }' "$SRC/$h" >> "$T/ienum"
done < "$T/ihdrs"
n_e=$(wc -l < "$T/ienum")
[ "$n_e" -gt 0 ] || { echo "FATAL: no enumerators read from the I headers"; exit 9; }

# Enumerators declared by each back end's insn-attr-common-<cpu>.h.
: > "$T/aenum"
n_a_files=0
for f in "$D"/insn-attr-common-*.h; do
  [ -f "$f" ] || continue
  n_a_files=$((n_a_files + 1))
  b=${f##*/insn-attr-common-}; b=${b%.h}
  tr '{},;' '\n\n\n\n' < "$f" \
    | awk -v b="$b" '
        /^[ \t]*[A-Z_][A-Za-z_0-9]*[ \t]*$/ {
          s = $1; if (s ~ /^[A-Z_][A-Za-z_0-9]*$/) print s, b
        }' >> "$T/aenum"
done
[ "$n_a_files" -gt 0 ] \
  || { echo "FATAL: no insn-attr-common-*.h in $D -- nothing to compare"; exit 9; }
n_ae=$(wc -l < "$T/aenum")
[ "$n_ae" -gt 0 ] \
  || { echo "FATAL: read $n_a_files attr headers and zero enumerators"; exit 9; }

echo "I headers: $n_i   enumerators in them: $n_e"
echo "insn-attr-common-*.h: $n_a_files   enumerators in them: $n_ae"
echo

echo "=== ATTR collisions (I-header enumerator == a back end's attr enumerator)"
sort -u "$T/ienum" | sort -k1,1 > "$T/i.s"
sort -u "$T/aenum" | sort -k1,1 > "$T/a.s"
join -j1 -o 0,1.2,2.2 "$T/i.s" "$T/a.s" | sort -u > "$T/hit"
n_hit=$(wc -l < "$T/hit")
awk '{ printf "%-28s %-40s %s\n", $1, $2, $3 }' "$T/hit"
echo "ATTR collision (name, I header, back end) triples: $n_hit"
echo "distinct colliding names: $(awk '{print $1}' "$T/hit" | sort -u | wc -l)"
echo

echo "=== IHDR collisions (same enumerator from two different I headers)"
sort -u "$T/ienum" | awk '{print $1}' | uniq -d > "$T/dup"
n_dup=$(wc -l < "$T/dup")
while read -r n; do
  printf '%-28s %s\n' "$n" "$(awk -v n="$n" '$1 == n { printf "%s ", $2 }' "$T/i.s")"
done < "$T/dup"
echo "IHDR collision names: $n_dup"
