#!/bin/sh
# THE OPTION-VOCABULARY LEAK: every name the generated options headers put at
# GLOBAL SCOPE in every translation unit of every back end, and what it
# collides with in TARGET-INDEPENDENT code.
#
# Third instrument in the same family:
#
#   mtO-optsmacro2.sh  the MACROS the `HeaderInclude' (`I') headers contribute
#                      -- closed by f3a75a98014 with a generated `#undef' block
#   mtq-enumleak.sh    the ENUMERATORS of the `I' headers, scored against the
#                      per-back-end insn-attr-common-<cpu>.h enumerators
#   THIS SCRIPT        the same enumerators PLUS the option VARIABLE names,
#                      scored against the shared middle end
#
# The third arm exists because the second one asked the wrong question.  It
# compared back-end vocabulary against back-end vocabulary, so it could only
# ever find collisions between two back ends.  The three walls this script was
# written for are all back end vs SHARED code:
#
#   `loop'          i386 `stringop_alg' enumerator vs `class loop' (cfgloop.h)
#   `libcall'       i386 `stringop_alg' enumerator
#   `selected_arch' aarch64 `TargetVariable' vs arm's own local
#
# A collision with the shared middle end is strictly worse than one between
# two back ends: it is not "these two back ends cannot be configured together",
# it is "this name is now unusable in 48 back ends AND in target-independent
# code", and the diagnostic names neither authority.
#
# TWO POPULATIONS
#
#   OPT   names put at global scope by the generated options headers:
#           * enumerators of the `I' headers, transitively (same reader as
#             mtq-enumleak.sh -- `TUNE_GENERIC' is declared in a file INCLUDED
#             BY an `I' header, so a non-transitive read returns the
#             reassuring answer);
#           * `extern <type> <name>;' lines of the generated options.h, which
#             is where `Var()' and `TargetVariable' land.
#   SHARED  type names (`class'/`struct'/`union'/`enum'/`typedef') and
#           `extern' variables declared at global scope in gcc/*.h --
#           target-independent headers only, NOT gcc/config/.
#
# CLASSIFIED, because the two halves fail differently:
#
#   TYPE  the shared name is a TYPE.  This is the LOUD one and it is loud in a
#         way that names neither party: an enumerator hides a class name of
#         the same name, so `loop *loop = alloc_loop ();' stops being a
#         declaration and becomes a multiplication --
#         `error: cannot convert `stringop_alg' to `loop*''.
#   VAR   the shared name is a variable.  Two `extern' declarations of
#         different type -> `conflicts with a previous declaration'.
#
# NON-VACUITY, per PRINCIPLES section 7: this script refuses to score if
# either population read empty, and refuses if its own three known-live
# witnesses (`loop', `libcall', `selected_arch') are absent from OPT -- an
# all-empty read is indistinguishable from "nothing collides", which is the
# answer it is trying to disprove.  Set WITNESS= to run it after the fix, when
# the witnesses are SUPPOSED to be gone.
#
# BLIND SPOTS, stated rather than left to be rediscovered:
#
#  * the readers are line matchers, not parsers.  Over-broad on purpose: this
#    instrument can only ever ADD a suspect, never clear one (PRINCIPLES 4).
#    Known false positives are macro parameters spelled in caps on their own
#    line (`ENUM_VALUE' in c6x-opts.h / m68k-opts.h).
#  * the transitive walk over the `I' headers is ONE level.
#  * SHARED is read from gcc/*.h only -- not gcc/c-family, gcc/cp, gcc/*/*.h.
#    A collision with a front end's header is real and is NOT scored here.
#  * a name that collides only in a header not reached by any TU still scores.
#
# usage: mtr-optvocab.sh <builddir>/gcc
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/../gcc" && pwd)
D=${1:?builddir/gcc}
[ -d "$D" ] || { echo "FATAL: $D is not a directory"; exit 9; }
[ -f "$D/options.h" ] || { echo "FATAL: no generated options.h in $D"; exit 9; }

T=$(mktemp -d)
trap 'rm -rf "$T"' 0

# ---- OPT half A: enumerators of the `I' headers, transitively. -------------
awk '/^HeaderInclude$/ { getline h; print h }' "$SRC"/config/*/*.opt \
  | sort -u > "$T/ihdrs0"
[ -s "$T/ihdrs0" ] || { echo "FATAL: no HeaderInclude headers found"; exit 9; }
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

: > "$T/opt"
while read -r h; do
  awk -v h="$h" '
    /^[ \t]*[A-Za-z_][A-Za-z_0-9]*[ \t]*(=[^;]*)?,?[ \t]*$/ {
      s = $0
      sub(/^[ \t]*/, "", s); sub(/[ \t]*(=.*)?,?[ \t]*$/, "", s)
      if (s ~ /^[A-Za-z_][A-Za-z_0-9]*$/) print s, "ENUMERATOR", h
    }
    # X-macro form.  i386-opts.h declares `enum stringop_alg'"'"' by including
    # stringop.def, whose lines read `DEF_ALG (loop, loop)'"'"' -- the enumerator
    # is a MACRO ARGUMENT and no line-per-enumerator reader can see it.  The
    # first draft of this script could not see `loop'"'"', i.e. it could not see
    # the wall it was written for, and said so only because the witness arm
    # made an empty read fatal.
    /^[ \t]*[A-Z_][A-Z_0-9]*[ \t]*\([ \t]*[A-Za-z_][A-Za-z_0-9]*[ \t]*[,)]/ {
      s = $0
      sub(/^[^(]*\([ \t]*/, "", s); sub(/[ \t]*[,)].*/, "", s)
      if (s ~ /^[A-Za-z_][A-Za-z_0-9]*$/) print s, "ENUMERATOR", h
    }' "$SRC/$h" >> "$T/opt"
done < "$T/ihdrs"
n_enum=$(wc -l < "$T/opt")
[ "$n_enum" -gt 0 ] || { echo "FATAL: no enumerators read from the I headers"; exit 9; }

# ---- OPT half B: option variables declared by the generated options.h. -----
# `Var()' and `TargetVariable' both land here as `extern <type> <name>;'.
sed -n 's/^extern[ \t].*[ \t*]\([A-Za-z_][A-Za-z_0-9]*\)[ \t]*;.*/\1/p' \
  "$D/options.h" | sort -u \
  | awk '{ print $1, "OPTVAR", "options.h" }' >> "$T/opt"
n_var=$(( $(wc -l < "$T/opt") - n_enum ))
[ "$n_var" -gt 0 ] || { echo "FATAL: no extern declarations read from options.h"; exit 9; }

sort -u "$T/opt" -o "$T/opt"

# ---- SHARED: global declarations in target-independent gcc/*.h. ------------
# Types first.
: > "$T/shared"
for f in "$SRC"/*.h; do
  b=${f##*/}
  sed -n \
    -e 's/^\(class\|struct\|union\|enum\)[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\)[ \t]*[{:;].*/\2/p' \
    -e 's/^typedef[ \t].*[ \t*]\([A-Za-z_][A-Za-z_0-9]*\)[ \t]*;.*/\1/p' \
    "$f" | awk -v b="$b" '{ print $1, "TYPE", b }' >> "$T/shared"
  sed -n 's/^extern[ \t].*[ \t*]\([A-Za-z_][A-Za-z_0-9]*\)[ \t]*;.*/\1/p' \
    "$f" | awk -v b="$b" '{ print $1, "VAR", b }' >> "$T/shared"
done
sort -u "$T/shared" -o "$T/shared"
n_sh=$(wc -l < "$T/shared")
[ "$n_sh" -gt 0 ] || { echo "FATAL: no declarations read from $SRC/*.h"; exit 9; }

echo "OPT names: $(awk '{print $1}' "$T/opt" | sort -u | wc -l)" \
     "(enumerator lines $n_enum, options.h extern lines $n_var)"
echo "SHARED declarations in $SRC/*.h: $n_sh"
echo

# ---- NON-VACUITY: the three live witnesses must be present in OPT. ---------
WITNESS=${WITNESS-loop libcall selected_arch}
miss=
for w in $WITNESS; do
  awk -v w="$w" '$1 == w { f = 1 } END { exit !f }' "$T/opt" || miss="$miss $w"
done
[ -z "$miss" ] || {
  echo "FATAL: witness(es) absent from the OPT population:$miss"
  echo "  An empty read looks exactly like 'nothing collides'.  If these are"
  echo "  gone because they were FIXED, re-run with WITNESS= to skip this arm."
  exit 9
}

# ---- score ----------------------------------------------------------------
sort -k1,1 "$T/opt" > "$T/opt.s"
sort -k1,1 "$T/shared" > "$T/shared.s"
join -j1 -o 0,1.2,1.3,2.2,2.3 "$T/opt.s" "$T/shared.s" | sort -u > "$T/hit"

printf '%-20s %-11s %-34s %-5s %s\n' NAME OPT-KIND OPT-SITE KIND SHARED-SITE
awk '{ printf "%-20s %-11s %-34s %-5s %s\n", $1, $2, $3, $4, $5 }' "$T/hit"
echo
echo "collision (name, opt site, shared site) rows: $(wc -l < "$T/hit")"
echo "distinct colliding names:                    $(awk '{print $1}' "$T/hit" | sort -u | wc -l)"
echo "  of which the shared side is a TYPE:        $(awk '$4=="TYPE"{print $1}' "$T/hit" | sort -u | wc -l)"
echo "  of which the shared side is a VAR:         $(awk '$4=="VAR"{print $1}' "$T/hit" | sort -u | wc -l)"
