#!/bin/sh
# #155 -- YOUR GREP'S --include LIST CAN EXCLUDE THE ANSWER.
#
# t155-classify.sh searches *.cc, *.c and *.h.  GCC's shared build also reads
# *.def (passes.def, target.def, builtins.def), *.opt, *.md and generated
# makefiles, and a name spelled in one of those is just as much a shared
# reference as one in a .cc.  A real case on this branch: a search for what
# invoked gen-reg-widths.sh used exactly such an --include list and concluded
# NOTHING invoked it; the invocation was in a *.awk file.
#
# `make_pass_insert_bti' is the name that prompted this -- a pass constructor,
# and pass constructors are named in passes.def, which the classifier could not
# see.  (It turns out arm and aarch64 register it from their OWN *-passes.def,
# so it is safe; the point is that the classifier could not have told me that.)
#
# usage: t155-nonsrc.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
M="$G/Makefile.in"
awk '/^MULTI_TARGET_RENAME_NAMES = /,/[^\\]$/' "$M" \
  | sed 's/^MULTI_TARGET_RENAME_NAMES = //; s/\\$//' \
  | tr -s ' \t' '\n' | grep . > /tmp/t155-ren2.txt
n=$(grep -c . /tmp/t155-ren2.txt)
[ "$n" -gt 5 ] || { echo "REFUSING TO SCORE: parsed only $n names"; exit 9; }

# Non-vacuity: the search must be able to FIND something in these file types.
#
# The first control here was `make_pass_vrp' and it found NOTHING, because
# passes.def spells `pass_vrp' -- the `make_' prefix is added by
# gen-pass-instances.awk.  The refusal fired, which is the arm working: a
# control that cannot find itself would otherwise have cleared all 48 names.
ctl=$(grep -rlw "pass_build_cfg" "$G" --include='*.def' 2>/dev/null | head -1)
[ -n "$ctl" ] || { echo "REFUSING TO SCORE: control pass_build_cfg not found in any .def"; exit 9; }
echo "arm 0 ok: $n names; control pass_build_cfg found in ${ctl#"$G/"}"

hits=0
while read -r name; do
  h=$(grep -rlw "$name" "$G" \
        --include='*.def' --include='*.opt' --include='*.md' --include='*.awk' \
        --include='*.in' --include='*.pd' 2>/dev/null \
      | grep -v "^$G/config/" | grep -v '/testsuite/' \
      | grep -v "^$M\$")
    # Makefile.in is excluded because it CONTAINS the rename list: every name
    # matches itself there, and the first run duly reported 48 of 48, which is
    # the shape of a check that is measuring its own input.
  if [ -n "$h" ]; then
    echo "  SHARED NON-SOURCE REFERENCE  $name"
    echo "$h" | sed "s|^$G/|      |"
    hits=$((hits+1))
  fi
done < /tmp/t155-ren2.txt
echo "  $hits of $n names referenced from shared non-.cc files"
