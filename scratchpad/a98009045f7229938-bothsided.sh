#!/bin/sh
# BOTH-SIDED, ACROSS ALL 45 TARGETS RATHER THAN FOUR COLUMNS.
#
# The claim under test has two halves and one-sided evidence cannot separate
# them (PRINCIPLES): showing the DFA-less back ends now compile proves nothing
# unless the back ends that HAVE an automaton are shown to be untouched.
#
# Four testsuite columns are the usual instrument for the second half.  This
# is a stronger one for THIS change and a weaker one in general, and both
# halves of that sentence are meant:
#
#   STRONGER -- it covers all 45 targets with a specs-config, not 4, and it
#   compares EMITTED TEXT, which is what a `scan-assembler' test reads.  The
#   change adds one conjunct to seven gates; for a base with `has_dfa == true'
#   that conjunct is the constant `true', so ANY byte of difference in that
#   population is a finding, and byte-identity is the strongest available
#   negative.
#
#   WEAKER -- one function is not a test suite.  It cannot see a difference
#   that needs a loop, a call, or vector code to appear, and it says nothing
#   about `check-function-bodies'.  Stated so this is not quoted as a suite
#   run.
#
# THE PARTITION IS PREDICTED BEFORE IT IS MEASURED, which is what makes this
# an arm rather than a report: every back end with an automaton must be
# IDENTICAL, and a difference there is a regression; a back end without one
# may differ, and if NONE of them did the change would have done nothing --
# so the script refuses a run in which no DFA-less target moved.
#
# usage: PRE=<builddir> POST=<builddir> a98009045f7229938-bothsided.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
PRE=${PRE:?pre build dir}
POST=${POST:?post build dir}
VER=$(cat "$(cat "$PRE/MY-SRC")/gcc/BASE-VER")
T=$(mktemp -d)
printf 'int f(int x){return x+1;}\n' > "$T/f.c"

# Which back ends have an automaton, read from the POST build's own generated
# headers -- the same authority the compiler used, not a list typed here.
have=""
for h in "$POST"/gcc/insn-attr-common-*.h; do
  b=$(basename "$h" .h); b=${b#insn-attr-common-}
  grep -q '^#define INSN_SCHEDULING$' "$h" && have="$have $b"
done
[ -n "$have" ] || { echo "FATAL: no back end has an automaton per the POST
headers -- that is a statement about this grep.  Refusing."; exit 9; }

same_dfa=0; diff_dfa=0; same_no=0; diff_no=0; onlyone=0
REG=""
printf '%-30s %-6s %s\n' TARGET DFA VERDICT
for d in "$PRE"/lib/gcc/"$VER"/*/; do
  TGT=$(basename "$d")
  [ -f "$d/specs-config" ] || continue
  [ -f "$POST/lib/gcc/$VER/$TGT/specs-config" ] || continue
  # The back end behind a triple: the mt-<base> the specs-config names is not
  # available here, so map by asking the compiler nothing and instead matching
  # the triple's cpu against the header list.  A target whose base cannot be
  # decided is reported as UNKNOWN rather than assumed into either bucket.
  # THE TRIPLE -> BACK END MAP IS A LOOKUP, NOT A STRING GUESS.  The first
  # draft matched the triple's prefix against the base name and got three
  # wrong in one run -- `x86_64-pc-linux-gnu' is i386, `hppa64-...' is pa,
  # `powerpc64-...' is rs6000, and none of those three names is a prefix of
  # its own back end.  All three were mislabelled NO-DFA.  It did not change
  # the verdict here (they were IDENTICAL either way), and it would have
  # inverted it for any of them that moved: a regression in a DFA back end
  # would have been filed under the bucket that is ALLOWED to differ.
  # `agent-acda89931a903ec27-backends.txt' is `<base>:<triple>:<exp>' and is
  # the committed authority.
  base=$(awk -F: -v t="$TGT" '$2==t{print $1}' \
           "$S/agent-acda89931a903ec27-backends.txt")
  [ -n "$base" ] || { echo "FATAL: no back end recorded for triple $TGT in
agent-acda89931a903ec27-backends.txt.  Refusing rather than guessing -- a
guessed base puts the row in the wrong bucket silently."; exit 9; }
  case " $have " in *" $base "*) ;; *) base="" ;; esac
  a=$("$PRE/gcc/xgcc"  -B"$PRE/gcc/"  -ftarget-config="$d/specs-config" \
        -O2 -S -o "$T/a.s" "$T/f.c" 2>&1; echo "rc=$?")
  b2=$("$POST/gcc/xgcc" -B"$POST/gcc/" \
        -ftarget-config="$POST/lib/gcc/$VER/$TGT/specs-config" \
        -O2 -S -o "$T/b.s" "$T/f.c" 2>&1; echo "rc=$?")
  ok_a=$(echo "$a"  | grep -c '^rc=0$')
  ok_b=$(echo "$b2" | grep -c '^rc=0$')
  if [ -n "$base" ]; then tag=DFA; else tag=NO-DFA; fi
  if [ "$ok_a" = 1 ] && [ "$ok_b" = 1 ]; then
    if cmp -s "$T/a.s" "$T/b.s"; then
      printf '%-30s %-6s IDENTICAL\n' "$TGT" "$tag"
      [ "$tag" = DFA ] && same_dfa=$((same_dfa+1)) || same_no=$((same_no+1))
    else
      printf '%-30s %-6s DIFFERS  (%s -> %s bytes)\n' "$TGT" "$tag" \
        "$(wc -c < "$T/a.s")" "$(wc -c < "$T/b.s")"
      if [ "$tag" = DFA ]; then diff_dfa=$((diff_dfa+1)); REG="$REG $TGT"
      else diff_no=$((diff_no+1)); fi
    fi
  elif [ "$ok_a" = 0 ] && [ "$ok_b" = 1 ]; then
    printf '%-30s %-6s FIXED (was failing, now emits)\n' "$TGT" "$tag"
    onlyone=$((onlyone+1))
  elif [ "$ok_a" = 1 ] && [ "$ok_b" = 0 ]; then
    printf '%-30s %-6s *** BROKEN (emitted before, fails now)\n' "$TGT" "$tag"
    REG="$REG $TGT"
  else
    printf '%-30s %-6s both fail (unchanged wall)\n' "$TGT" "$tag"
  fi
done
rm -rf "$T"

echo
echo "HAS an automaton : IDENTICAL $same_dfa   DIFFERS $diff_dfa"
echo "NO  automaton    : IDENTICAL $same_no    DIFFERS $diff_no   FIXED $onlyone"
echo
rc=0
if [ -n "$REG" ]; then
  echo "REGRESSION:$REG"; rc=1
fi
# The two refusals that make a null result impossible to read as a pass.
if [ "$((same_dfa+diff_dfa))" = 0 ]; then
  echo "FATAL: ZERO back ends with an automaton were compared.  That is what a
broken triple->base mapping prints, and it is also what 'no regressions'
prints.  Refusing."; rc=9
fi
if [ "$((onlyone+diff_no))" = 0 ]; then
  echo "FATAL: NOT ONE DFA-less target changed.  The two compilers are then
indistinguishable on this input, so the IDENTICAL column above is evidence
about the fixture and not about the fix.  Refusing."; rc=9
fi
exit $rc
