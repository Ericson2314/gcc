#!/usr/bin/env bash
#
# REGENERATE THE TAB REFERENCE DATASET (`/tmp/mtp-before').
#
# WHY THIS SCRIPT EXISTS
#   tab-probe.sh scores the four string (c-DATA) macros -- ASM_COMMENT_START,
#   WCHAR_TYPE, SIZE_TYPE, PTRDIFF_TYPE -- against an INDEPENDENT measurement:
#   `$MTP/str-<base>.txt', produced by macro-probe.sh.  Once a macro is
#   CONVERTED_CDATA its header arm is RETIRED by design, so a macro-probe run
#   over HEAD does not measure those four at all and CANNOT repopulate the
#   reference.  The reference must come from a tree that predates the
#   conversion, and there is exactly one such tree.
#
#   `/tmp/mtp-before' was overwritten once by a post-Stage-2 run.  The symptom
#   was five TAB arms red with "no independent value", which reads like a code
#   regression and is not one; it cost two agents a session.  Hence: this
#   script, the provenance file it writes, and the abort tab-probe.sh now does.
#
# PROVENANCE COMMIT: 36ba31303e20ce06b306216105f7d5d18d2897b4
#   the last commit before b063704e8a9 ("per-config slots for four (c-DATA)
#   macros"), which is the commit that retired those four header arms.
#
# METHOD, AND WHY IT IS NOT A FULL BUILD OF THE OLD TREE
#   macro-probe.sh never runs cc1.  It compiles probe sources with the HOST g++
#   against the build directory's generated headers and the SOURCE tree that
#   the script itself lives in ($HERE/../gcc).  So running the OLD tree's copy
#   of macro-probe.sh against the CURRENT build directory measures the old
#   headers -- which is exactly what is wanted, because the only thing that
#   changed for these four macros is gcc/defaults.h.
#
#   A cold build of the provenance commit was tried first and does not work:
#   36ba31303e2 predates bd73cec500c ("make a from-scratch build work"), so
#   `build/genconstants' dies in the insn-constants.h cycle and, past that,
#   `all-tree.def' is missing.  That is a property of that commit, not of this
#   host.
#
#   The mismatch (old source, current build dir) is NOT taken on trust.  Step 5
#   below re-scores every arm the two datasets have in common and requires them
#   to be identical; only the eight retired arms may be new.  If the build dir
#   perturbed anything, that check is where it shows.
#
# USAGE
#   scratchpad/mtp-before-regen.sh [builddir] [dest]
#   defaults: /tmp/b-objs  /tmp/mtp-before
#   POST=<dir>  a post-conversion macro-probe run to cross-check against
#               (default /tmp/mtp-out if it exists)
set -u

BUILD=${1:-/tmp/b-objs}
DEST=${2:-/tmp/mtp-before}
WT=${WT:-/tmp/wt-mtpbefore}
COMMIT=36ba31303e20ce06b306216105f7d5d18d2897b4
REPO=$(cd "$(dirname "$0")/.." && pwd)
TMPOUT=${TMPOUT:-/tmp/mtp-before-new}

die () { echo "FATAL: $*" >&2; exit 9; }

# The four macros this dataset exists to carry.  If they are not in the result
# the run was not a pre-conversion run and the dataset must not be installed.
RETIRED="ASM_COMMENT_START WCHAR_TYPE SIZE_TYPE PTRDIFF_TYPE"

########################################################################
# 1.  A worktree at the provenance commit, and proof that it IS that commit.
########################################################################
if [ ! -d "$WT/gcc" ]; then
  git -C "$REPO" worktree add "$WT" "$COMMIT" > /tmp/wt-add.out 2> /tmp/wt-add.err \
    || { cat /tmp/wt-add.err; die "could not create worktree $WT"; }
fi
GOT=$(git -C "$WT" rev-parse HEAD)
[ "$GOT" = "$COMMIT" ] || die "$WT is at $GOT, expected $COMMIT"

########################################################################
# 2.  The discriminator.  "It is the right commit" is a claim about a hash;
#     this is a claim about the file that matters.  At the provenance commit
#     defaults.h must NOT redirect ASM_COMMENT_START to a target-cdata slot.
#     (Same regexp tab-probe.sh's `redirected' uses, so the two agree on what
#     "converted" means.)
########################################################################
if grep -qE '^#define ASM_COMMENT_START \(targetm_cdata\.' "$WT/gcc/defaults.h"; then
  die "$WT/gcc/defaults.h redirects ASM_COMMENT_START -- this is a POST-conversion tree"
fi
# And the control for that check: the CURRENT tree must answer the other way.
# A check that says "not redirected" about everything proves nothing.
grep -qE '^#define ASM_COMMENT_START \(targetm_cdata\.' "$REPO/gcc/defaults.h" \
  || die "control: the CURRENT tree does not redirect ASM_COMMENT_START either, so the
pre/post discriminator answers 'no' to everything and cannot tell the trees apart"
echo "ok: $WT is pre-conversion, and the check still says the current tree is post-conversion"

########################################################################
# 3.  Run the OLD tree's macro-probe.
########################################################################
[ -f "$WT/scratchpad/macro-probe-run.sh" ] || die "no macro-probe-run.sh in $WT/scratchpad"
[ -d "$BUILD/gcc" ] || die "no build dir $BUILD/gcc"
rm -rf "$TMPOUT"
OUT="$TMPOUT" bash "$WT/scratchpad/macro-probe-run.sh" "$BUILD" \
  > /tmp/mtp-before-regen.out 2> /tmp/mtp-before-regen.err
rc=$?
echo "macro-probe (pre-conversion tree) rc=$rc"
[ $rc = 0 ] || { tail -20 /tmp/mtp-before-regen.err; die "macro-probe failed"; }

########################################################################
# 4.  The dataset must actually CARRY the retired arms.  This is the whole
#     point of the exercise; without it the script would happily install
#     another post-conversion run.
########################################################################
[ -s "$TMPOUT/str-aarch64.txt" ] || die "no $TMPOUT/str-aarch64.txt"
for m in $RETIRED; do
  awk -v m="$m" '$1==m{f=1} END{exit !f}' "$TMPOUT/str-aarch64.txt" \
    || die "$m has no aarch64 value in the fresh run -- that is the post-conversion
signature, so this run cannot serve as the TAB reference"
done
echo "ok: all four retired macros carry an aarch64 value"

########################################################################
# 5.  CROSS-CHECK.  The run above used the old SOURCE tree with the current
#     BUILD dir.  Every arm the two datasets share must score identically;
#     only the eight retired arms may be new.  This is what makes the mismatch
#     safe to rely on rather than merely plausible.
########################################################################
POST=${POST:-}
if [ -z "$POST" ] && [ -s /tmp/mtp-out/results.txt ]; then POST=/tmp/mtp-out; fi
if [ -n "$POST" ] && [ -s "$POST/results.txt" ]; then
  awk '{print $1"|"$2, $3"/"$4}' "$POST/results.txt"  | sort > /tmp/mtpx-post.txt
  awk '{print $1"|"$2, $3"/"$4}' "$TMPOUT/results.txt" | sort > /tmp/mtpx-new.txt
  join -j 1 -o 0,1.2,2.2 /tmp/mtpx-post.txt /tmp/mtpx-new.txt > /tmp/mtpx-join.txt
  ncommon=$(wc -l < /tmp/mtpx-join.txt)
  ndiff=$(awk '$2!=$3' /tmp/mtpx-join.txt | wc -l)
  nnew=$(comm -13 <(cut -d' ' -f1 /tmp/mtpx-post.txt) <(cut -d' ' -f1 /tmp/mtpx-new.txt) | wc -l)
  echo "cross-check vs $POST: common $ncommon  disagreeing $ndiff  new-only $nnew"
  [ "$ncommon" -gt 200 ] || die "only $ncommon arms in common with $POST; the two runs
are not comparable and the cross-check would be vacuous"
  [ "$ndiff" = 0 ] || { awk '$2!=$3' /tmp/mtpx-join.txt | head; \
    die "$ndiff shared arms disagree -- the old source / current build dir pairing
perturbed the measurement and this dataset must not be installed"; }
  XCHECK="$POST: $ncommon shared arms, 0 disagree, $nnew new"
else
  XCHECK="NOT RUN (no post-conversion dataset given; pass POST=<dir>)"
  echo "WARNING: cross-check $XCHECK"
fi

########################################################################
# 6.  Install, with provenance recorded INSIDE the dataset.  A reference whose
#     provenance is not written down is one overwrite away from the failure
#     this script was written to undo.
########################################################################
rm -rf "$DEST" || die "cannot remove $DEST"
cp -a "$TMPOUT" "$DEST" || die "cannot install $DEST"
cat > "$DEST/PROVENANCE.txt" <<EOF
MTP-PROVENANCE 1
commit    $COMMIT
subject   $(git -C "$WT" log -1 --format=%s)
generated $(date -Iseconds)
by        scratchpad/mtp-before-regen.sh
worktree  $WT
builddir  $BUILD
retired   $RETIRED
xcheck    $XCHECK

This is the PRE-(c-DATA) reference dataset.  tab-probe.sh reads the expected
bytes for the four macros listed on the 'retired' line from str-<base>.txt
here.  Those four macros are CONVERTED_CDATA at HEAD, their header arms are
retired, and a macro-probe.sh run over HEAD therefore CANNOT reproduce this
file -- it will silently produce a dataset without them, and every TAB arm for
them then fails with "no independent value", which looks like a code
regression and is not one.

DO NOT overwrite this directory with a macro-probe run over HEAD.
To rebuild it, run scratchpad/mtp-before-regen.sh.
EOF
echo "installed $DEST"
cat "$DEST/PROVENANCE.txt"
