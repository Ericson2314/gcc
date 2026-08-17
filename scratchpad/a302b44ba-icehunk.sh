#!/bin/sh
# a302b44ba-icehunk.sh -- the bisect named `3241754cf12'; this names WHICH OF
# ITS TWO HUNKS, and settles a reading that did not close.
#
# The bisect is already conclusive at commit granularity: index 112
# (`f1c3095db2c') says NO, index 113 (`3241754cf12') says YES.  But
# `3241754cf12' makes TWO independent changes, both "skip modes for which
# `MODE_IS_HOLE_P'":
#
#   A  setup_reg_class_nregs                    -- leaves ira_reg_class_max_nregs 0
#   B  setup_prohibited_and_exclude_class_mode_regs
#                                               -- leaves the two HARD_REG_SETs CLEARED
#
# AND THE READING PREDICTS NEITHER SHOULD FIRE HERE.  `MODE_IS_HOLE_P' reads
# `mode_class_index[MODE] == 0xffff', which is emitted PER BASE, and x86 really
# has TImode -- so on the x86 arm TImode should not be a hole and neither skip
# should trigger.  Something in that reading is wrong, and which hunk fires
# tells us what.
#
# WHY IT MATTERS RATHER THAN BEING TIDINESS.  If it is B, the defect is the one
# the commit message states in its own words -- "the two HARD_REG_SETs stay
# CLEARED ... both already mean 'nothing here'".  For
# `ira_prohibited_class_mode_regs' that is FALSE: cleared means NOTHING IS
# PROHIBITED, the maximally PERMISSIVE value, not the inert one.  The inert
# value for a prohibition table is SET.  That would make the bug a wrong choice
# of default rather than a wrong loop bound, and the fix a different one-liner.
#
# EACH ARM REVERTS EXACTLY ONE HUNK and is built and probed on its own; the
# unmodified commit is probed too, so an arm that "fixes" it cannot be confused
# with an arm that failed to build.
#
# usage: a302b44ba-icehunk.sh
set -u
export LC_ALL=C
S=$(cd "$(dirname "$0")" && pwd)
W=/home/jcericson/src/gnu/gcc/multi-target
C=3241754cf12
BASE=/tmp/icehunk-302b44ba
rm -rf "$BASE"; mkdir -p "$BASE"

mk () {   # mk <tag> <sed-program-applied-to-ira.cc>
  _t=$1; _sed=$2
  _src=$BASE/src-$_t
  mkdir -p "$_src"
  ( cd "$W" && git archive "$C" ) | tar -x -C "$_src" || return 9
  if [ -n "$_sed" ]; then
    cp "$_src/gcc/ira.cc" "$_src/ira.cc.orig"
    perl -0pi -e "$_sed" "$_src/gcc/ira.cc"
    if cmp -s "$_src/ira.cc.orig" "$_src/gcc/ira.cc"; then
      echo "FATAL[$_t]: the revert matched NOTHING -- ira.cc is unchanged."
      echo "  Building this would re-run the unmodified commit under the name"
      echo "  of a revert, which is the exact false-green this branch pays for."
      return 9
    fi
    rm -f "$_src/ira.cc.orig"
  fi
  ( cd "$W" && git rev-parse --short=11 "$C" ) > "$_src/SNAP-SHA"
  chmod -R a-w "$_src"
  out=$(sh "$S/a302b44ba-icebuild.sh" "$BASE/b-302b44ba-$_t" "$_src" 2>&1)
  printf '===== %s\n%s\n' "$_t" "$out" >> "$BASE/log"
  case "$out" in
    *"ICE: YES"*) echo YES ;;
    *"ICE: NO"*)  echo NO  ;;
    *)            echo BAD ;;
  esac
}

# Hunk B: drop the `if (MODE_IS_HOLE_P (j)) { ...; continue; }' block in
# setup_prohibited_and_exclude_class_mode_regs.
SEDB='s/\n\s*\/\* THE MODE AXIS:.*?\n\s*if \(MODE_IS_HOLE_P \(j\)\)\n\s*\{\n\s*ira_class_singleton\[cl\]\[j\] = -1;\n\s*continue;\n\s*\}//s'
# Hunk A: drop the `if (MODE_IS_HOLE_P (m)) continue;' in setup_reg_class_nregs.
SEDA='s/\n\s*\/\* AND THE MODE AXIS,.*?\n\s*if \(MODE_IS_HOLE_P \(m\)\)\n\s*continue;//s'

echo "== control: $C unmodified (want YES)"
c=$(mk ctl "");    echo "   $c"
echo "== arm A: hunk in setup_reg_class_nregs reverted"
a=$(mk revA "$SEDA"); echo "   $a"
echo "== arm B: hunk in setup_prohibited_and_exclude_class_mode_regs reverted"
b=$(mk revB "$SEDB"); echo "   $b"

echo
if [ "$c" != YES ]; then
  echo "HUNK: INCONCLUSIVE -- the unmodified commit did not reproduce (got '$c')."
  echo "  Nothing can be concluded about either arm.  See $BASE/log."
  exit 9
fi
case "$a$b" in
  YESNO) echo "HUNK: it is B -- setup_prohibited_and_exclude_class_mode_regs."
         echo "  Reverting B removes the ICE; reverting A does not.  So the defect is"
         echo "  leaving ira_prohibited_class_mode_regs CLEARED, which for a PROHIBITION"
         echo "  table is the maximally PERMISSIVE value, not the inert one the commit"
         echo "  message claims.  r15 is simply never marked as unable to hold TImode." ;;
  NOYES) echo "HUNK: it is A -- setup_reg_class_nregs (ira_reg_class_max_nregs left 0)." ;;
  NONO)  echo "HUNK: EITHER ALONE SUFFICES -- both reverts remove the ICE." ;;
  YESYES) echo "HUNK: NEITHER ALONE SUFFICES -- both reverted together would be needed,"
          echo "  or the cause is a third change in the same commit." ;;
  *)     echo "HUNK: INCONCLUSIVE -- arm A '$a', arm B '$b'.  See $BASE/log." ; exit 9 ;;
esac
echo "  log: $BASE/log"
