#!/bin/sh
# #171 PART B -- is a source that TWO back ends list in extra_objs really two
# objects, or one source compiled twice for no reason?
#
# The question the rename list cannot answer.  20 of MULTI_TARGET_RENAME_NAMES
# come from config/arm/aarch-common.cc and config/arm/aarch-bti-insert.cc,
# which config.gcc gives to BOTH aarch64 and arm (config.gcc:377, :424) -- the
# same shape as config/linux.cc, which is why three linux_* names are in that
# list too.  Renaming makes the link work; it does not say whether two copies
# are RIGHT.  If the two compilations produce the same code, two copies are
# duplication and the file should be compiled once and shared.  If they do
# not, one shared copy would bake one back end's answer into the other's,
# which is this project's whole bug.
#
# MEASURED, and the method matters more than the verdict:
#
#   * compile with THE BUILD'S OWN COMMAND, unmodified except for the output
#     path.  An earlier version stripped the `-D<name>=<name>_<base>' renames
#     so that symbol names could not masquerade as a difference in code.  That
#     is wrong twice: `-DMULTI_TARGET_TARGETM_BASE' has to go with them (or
#     target.h:403 #errors, which is that guard working), and removing it also
#     turns OFF defaults.h's conversion layer, so aarch-bti-insert.cc then
#     fails with `multiple definition of enum reg_class'.  The stripped
#     command is not the command the build runs and its object is not the
#     object under test.
#
#   * compare the DISASSEMBLY with the `_<base>' suffixes normalised away.
#     Renaming is then visibly not what is being measured, and the comparison
#     is of instructions.
#
#   * `nm --defined-only -S' was tried and is USELESS HERE, in a way worth
#     recording: the two objects are the same size and every symbol in them is
#     the same size, because the difference is an IMMEDIATE OPERAND.  A size
#     table reports `no defined symbol differs' -- the shape that reads as
#     `identical'.  (It also splits demangled C++ names on their commas, the
#     PRINCIPLES-4 awk-on-a-demangled-name trap arriving a second way.)
#
# NON-VACUITY: refuses to score unless a compile command was recovered for each
# base, each command carried renames (so it IS the build's command), and each
# produced a non-empty object.  An all-empty read is indistinguishable from
# `the two are identical'.
#
# THE PAIR IS A PARAMETER, and it has to be.  `identical for aarch64 and arm'
# is not `identical for every base': config/linux.cc is compiled for all eight,
# and two of them agreeing says nothing about the other six.  Run the pairs you
# mean to claim about.
#
# usage: [BASES="<b1> <b2>"] t171-partb.sh <build dir> [<source path under gcc/>]
set -u
BASES=${BASES:-"aarch64 arm"}
B1=${BASES%% *}
B2=${BASES##* }
[ "$B1" != "$B2" ] || { echo "FATAL: BASES must name two DIFFERENT back ends;"; \
  echo "  comparing a base with itself is green by construction."; exit 9; }
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
SRC_REL=${2:-config/arm/aarch-common.cc}
case "$D" in
  */b-a0e5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
OBJ=$(basename "$SRC_REL" .cc)
O=$D/partb-$OBJ
rm -rf "$O"; mkdir -p "$O"
echo "== $SRC_REL, in $D"

for b in $BASES; do
  sh "$S/eb-shell.sh" "cd $D/gcc && make -n mt-$b/$OBJ.o" \
    > "$O/$b.mk" 2> "$O/$b.mkerr"
  # THE LINE THAT NAMES THE OUTPUT OBJECT, not merely one mentioning the stem.
  # `make -n mt-aarch64/aarch-common.o' prints every recipe it would run to get
  # there -- the whole options-generation chain first -- and a grep for the
  # stem alone picks up `optionlist-aarch64.own', which is a gawk command.  It
  # then "succeeds", and the comparison is of two files that are not objects.
  cmd=$(grep -m1 -F -- "-o mt-$b/$OBJ.o" "$O/$b.mk" | sed 's/^[ \t]*//')
  if [ -z "$cmd" ]; then
    echo "FATAL: no compile command recovered for $b"
    cat "$O/$b.mkerr"; exit 9
  fi
  nren=$(printf '%s\n' "$cmd" | tr ' ' '\n' \
    | grep -c -E "^-D[A-Za-z_][A-Za-z0-9_]*=[A-Za-z_][A-Za-z0-9_]*_$b\$" || true)
  echo "  $b: command carries $nren rename -D flags"
  [ "$nren" -gt 0 ] || { echo "FATAL: no renames on $b's command -- this is not"; \
    echo "  the command the build uses."; exit 9; }
  out=$(printf '%s\n' "$cmd" | sed "s#-o [^ ]*#-o $O/$b.o#")
  sh "$S/eb-shell.sh" "cd $D/gcc && $out" > "$O/$b.out" 2> "$O/$b.err"
  echo "    compile rc=$?  stderr $(wc -l < "$O/$b.err") lines"
  [ -s "$O/$b.o" ] || { echo "FATAL: $O/$b.o is empty or absent"; \
    tail -20 "$O/$b.err"; exit 9; }
  # `-C' IS LOAD-BEARING, not a convenience.  The Itanium mangling encodes the
  # LENGTH of each identifier, so `_Z41aarch_validate_mbranch_protection_aarch64'
  # and `_Z37aarch_validate_mbranch_protection_arm' differ in the digits as
  # well as the suffix, and no `s/_<base>/_MT/' can normalise them.  Demangled,
  # the suffix is the only difference and the substitution works.  `-r' so that
  # calls to renamed symbols are normalised alongside the definitions.
  sh "$S/eb-shell.sh" "objdump -drC --no-show-raw-insn '$O/$b.o'" \
    | sed -e '1,2d' -e "s/_$b\\b/_MT/g" > "$O/$b.dis"
  [ -s "$O/$b.dis" ] || { echo "FATAL: empty disassembly for $b"; exit 9; }
done

echo
echo "  ($B1 vs $B2)"
diff "$O/$B1.dis" "$O/$B2.dis" > "$O/dis.diff"
if [ -s "$O/dis.diff" ]; then
  echo "  DIFFER: $(grep -c '^<' "$O/dis.diff") instructions, renames normalised away"
  sed 's/^/    /' "$O/dis.diff"
else
  echo "  IDENTICAL once the renames are normalised away."
  echo "  (An upper bound on similarity: identical code is not by itself proof"
  echo "   that one shared object would be correct for every FUTURE back end"
  echo "   that lists this file -- only that these two agree today.)"
fi
