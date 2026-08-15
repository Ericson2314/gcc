#!/bin/sh
# mt-regno-classifier-census.sh -- the REMAINING `FIRST_PSEUDO_REGISTER'
# CLASSIFIER sites in SHARED code, which are a different population from the
# BOUND sites and must not be converted together.
#
# THE DISTINCTION, which is the whole point of the script:
#
#   BOUND / LAYOUT   `for (i = 0; i < FIRST_PSEUDO_REGISTER; i++)',
#                    `HARD_REG_SET' widths, array sizes.  These correctly want
#                    the UNION's number -- it is how wide the shared object is.
#   CLASSIFIER       `regno < FIRST_PSEUDO_REGISTER' asking "is this a hard
#                    register".  These want the SELECTED BASE's number
#                    (`MT_FIRST_PSEUDO_REGISTER'), because the answer is a fact
#                    about the target being compiled for, not about the widest
#                    configured back end.
#
# WHY IT MATTERS NOW, measured at 47 bases on `cad1a29fbdc':
#
#     MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER   677
#     x86_64's own FIRST_PSEUDO_REGISTER          92
#
# so regnos 92..676 are genuine x86_64 PSEUDOS that every surviving classifier
# site calls hard registers.  `recog.cc:1598' is the live one:
#
#     return (REGNO (op) >= FIRST_PSEUDO_REGISTER            <- the UNION, 677
#             || in_hard_reg_set_p (operand_reg_set, ..., REGNO (op)));
#                  `- gcc_assert (HARD_REGISTER_NUM_P (regno))  <- the BASE, 92
#
# The two halves of one expression now disagree, so a pseudo numbered 100 fails
# the `>=' test, reaches `in_hard_reg_set_p', and aborts.  1,764 ICEs on x86_64
# in that one site.  THE ASSERT IS NOT THE BUG -- it is the converted half
# correctly reporting the unconverted half, and before `HARD_REGISTER_NUM_P'
# was converted the same expression silently returned a WRONG ANSWER instead.
#
# THE BAND WIDENS WITH THE BASE SET, which is why this is louder here than on
# any previous board: 92..127 at four bases (union 128), 92..676 at 47.  A
# figure from this script is therefore meaningless without its base count.
#
# THIS SCRIPT IS NOT THE AUTHORITY ON THIS POPULATION AND MUST NOT BECOME ONE.
# `A57163422943AAA57-REGNO-CLASSIFIER-QUEUE.md' already owns it, already
# counts it (176 sites whose operand is `REGNO (...)' plus ~147 spelled with a
# bare variable), and -- far more importantly -- already carries the CRITERION,
# which is the part that cannot be derived from a grep:
#
#   A CONSUMER'S CLASSIFIER MAY ONLY BE CONVERTED IF EVERY PRODUCER THAT
#   POPULATES THE STRUCTURES ITS PSEUDO-BRANCH TOUCHES USES THE SAME NUMBER.
#
# That document was paid for with a withdrawn 176-site sweep that built clean
# and then segfaulted the x86_64 bar in `record_operand_costs', because
# `ira-build.cc' creates allocnos only from the UNION's number, so a correctly
# classified pseudo indexed an allocno map that had no entry for it.  Read it
# BEFORE converting anything this script prints.  It also predicted this
# board's finding exactly, from a 200-command replay: "7 hit
# `in_hard_reg_set_p, at regs.h:312' from `recog.cc:1598'".  What is new here
# is only the SCALE at full-suite, 47-base size -- 1,764 -- and the band width
# that explains it.
#
# The count this prints is deliberately BROADER than the queue document's
# (it also takes `>=', `>', `<=' and the reversed operand order, and it reads
# headers as well as `.cc'), so the two numbers are not in conflict and
# NEITHER supersedes the other.  Quote the queue document for the population
# and the method; quote this only for the band and the non-vacuity arm.
#
# The output is DELIBERATELY OVER-BROAD.  It can only ever nominate a site for
# a human to classify; it must never be read as authorising a mechanical
# rewrite.  PRINCIPLES: "when an instrument can only take away, make it too
# eager; when it can grant, make it exact" -- and a `sed' over this population
# is exactly the bulk rewrite that produced 16 silent corruptions from
# `DF_REF_REGNO' last time.  Convert by hand, per site.
#
# usage: mt-regno-classifier-census.sh <srcdir>
set -u
SRC=${1:?srcdir}
cd "$SRC/gcc" || exit 9

# NON-VACUITY FIRST, and it is not a formality: this whole script is a pattern
# that can silently match nothing, which is the shape that reads as "the
# population is empty, the work is done".  `recog.cc:1598' is a site that MUST
# appear; if it does not, the pattern is broken, not the tree clean.
probe=$(grep -c 'REGNO (op) >= FIRST_PSEUDO_REGISTER' recog.cc || true)
[ "$probe" -ge 1 ] || {
  echo "FATAL: the known site recog.cc:1598 did not match."
  echo "  This script's pattern is broken.  An empty census from a broken"
  echo "  pattern is indistinguishable from a converted tree; refusing."
  exit 9
}
echo "-- non-vacuity: the known unconverted site recog.cc matches ($probe hits)"

# SHARED code only.  `gcc/config/' is per-back-end and compiled with -DMT_BASE,
# where the bare name is that base's own answer and is CORRECT.
echo
echo "-- CLASSIFIER-SHAPED sites (a REGNO compared against the bare name), by file"
grep -rn --include='*.cc' --include='*.h' \
  -E '(REGNO[ ]*\([^)]*\)|regno|REGNO)[ ]*(<|>=|<=|>)[ ]*FIRST_PSEUDO_REGISTER|FIRST_PSEUDO_REGISTER[ ]*(<=|>|>=|<)[ ]*(regno|REGNO)' \
  . 2>/dev/null \
  | grep -v '^\./config/' \
  | grep -v 'MT_FIRST_PSEUDO_REGISTER' \
  | tee /tmp/mt-regno-census.$$ \
  | awk -F: '{print $1}' | sort | uniq -c | sort -rn

echo
echo "-- total classifier-shaped sites in shared code: $(wc -l < /tmp/mt-regno-census.$$)"
echo
echo "-- the sites themselves (convert BY HAND, one at a time):"
sed 's/^/    /' /tmp/mt-regno-census.$$
rm -f /tmp/mt-regno-census.$$
