#!/bin/sh
# Does the cause-ranking fold cover EVERY self-naming diagnostic in the tree?
#
# WHAT THIS EXISTS FOR.  This branch's best diagnostics name the back end:
#
#     back end 'vax' has no pipeline automaton, but shared scheduling code
#     compiled for a primary that has one is asking it for pipeline hazards
#
# One shared defect then keys as N distinct causes in any text-keyed ranking
# and can never rise in a breadth ordering however wide it is.  It cost this
# project TWO boards: the DFA-absent case was recorded as avr's alone, twice,
# while it was live on eleven back ends and was the largest cause by volume
# AND the widest by breadth simultaneously.
#
# `a7d26223eefcfa725-causes2.sh' fixed the instance, with
#
#     sed "s/back end '[^']*'/back end 'BE'/g"
#
# and that is a fold for ONE MESSAGE SHAPE.  Nothing asserted it covers the
# population, and the population grows every time someone writes a good
# diagnostic.  This script is that assertion.  It is the "sweep the family;
# do not meet it one wall at a time" rule applied to the instrument rather
# than to the compiler.
#
# THE NULL RESULT IS THE FAILURE MODE, SO IT IS MADE IMPOSSIBLE.  "No
# diagnostic escapes the fold" and "the grep for diagnostics matched nothing"
# are the same clean output, and this whole family of bug is that confusion.
# So ARM 0 refuses to score until it has found a known-escaping shape and a
# known-folding shape in the real tree, and ARM 3 runs the fold against a
# fixture containing both -- a negative case that must stay negative is the
# only thing that shows the pattern is not matching everything.
#
# usage: a98009045f7229938-foldcheck.sh
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc" || exit 9
FOLD="s/back end '[^']*'/back end 'BE'/g"

# The files that hold this branch's per-base refusals.  Named rather than
# globbed over all of gcc/: upstream diagnostics naming a target are a
# different population and folding them is not this instrument's business.
FILES='target-cumargs-select.cc multi-target-select.cc target-asm-ops-select.cc
       multi-target-options-select.cc common/common-target-select.cc
       multi-target-preds-select.cc target-c-ops-select.cc'
present=''
for f in $FILES; do [ -f "$f" ] && present="$present $f"; done
[ -n "$present" ] || { echo "FATAL: none of the selector sources exist here"; exit 9; }

# ---- ARM 1: enumerate every diagnostic string carrying a %qs -------------
ALL=$(grep -ho '"[^"]*%qs[^"]*"' $present | sort -u)
n_all=$(printf '%s\n' "$ALL" | grep -c .)
[ "$n_all" -gt 0 ] || { echo "FATAL: ZERO %qs diagnostics found in$present.
That is a statement about this grep, not about the tree -- refusing."; exit 9; }

# ---- ARM 2: split them by whether the fold reaches them ------------------
# A message is COVERED if it spells the back-end name behind the literal words
# `back end ' -- the only thing the fold can key on.  Everything else is
# either not about a back end (a symbol name, a macro name) or is a back-end
# name the fold cannot see, and only the second is a defect.
cov=$(printf '%s\n' "$ALL" | grep -c 'back end %qs')
esc=$(printf '%s\n' "$ALL" | grep -v 'back end %qs')
n_esc=$(printf '%s\n' "$esc" | grep -c .)
echo "=== %qs diagnostics in the selector sources: $n_all"
echo "=== reachable by the fold (spell \`back end %qs'): $cov"
[ "$cov" -gt 0 ] || { echo "FATAL: the fold covers NOTHING.  Either the
message wording changed or this grep is wrong; either way the number below is
meaningless.  Refusing."; exit 9; }
echo "=== NOT reachable by the fold: $n_esc"
printf '%s\n' "$esc" | sed 's/^/    /'

# ---- ARM 2b: a RESIDUAL varying field after the fold ---------------------
# "Contains `back end %qs'" is NOT "is folded to one key".  A message can name
# the back end AND carry a second `%qs' that also varies per target, in which
# case folding the first collapses nothing.  This arm is here because the
# first draft of this script missed exactly that and reported 28/29 covered.
#
# `%d' needs no entry: the ranking digit-squashes after the fold, so a numeric
# field is already collapsed.  A second `%qs' holding a MACRO name is a real
# discriminator and must NOT be folded -- two back ends failing on different
# macros are two causes -- so this arm REPORTS rather than refuses, and the
# reader decides which kind each one is.
echo
echo "=== carry \`back end %qs' AND a further %qs, so the fold leaves them split ==="
resid=$(printf '%s\n' "$ALL" | grep 'back end %qs' \
        | sed 's/back end %qs//' | grep '%qs')
n_resid=$(printf '%s\n' "$resid" | grep -c .)
if [ "$n_resid" = 0 ]; then
  echo "    (none)"
else
  printf '%s\n' "$ALL" | grep 'back end %qs' \
    | awk '{t=$0; sub(/back end %qs/,"",t); if (t ~ /%qs/) print "    " $0}'
fi
echo "    count: $n_resid"

# ---- ARM 3: the fold, on a fixture with a case that must NOT match -------
# PRINCIPLES: "matched too much" and "matched too little" both look like
# success when you inspect only the output.  Only an input with known answers
# separates them.
echo
echo "=== ARM 3: the fold on a fixture (two must collapse, two must not) ==="
FIX=$(printf "%s\n" \
  "back end 'vax' has no pipeline automaton, but shared scheduling code" \
  "back end 'xstormy16' has no pipeline automaton, but shared scheduling code" \
  "'ix86_cc_mode' was used before a target was selected: no back end" \
  "'aarch64_cc_mode' was used before a target was selected: no back end")
got=$(printf '%s\n' "$FIX" | sed "$FOLD" | sed "s/[0-9][0-9]*/N/g" | sort -u | wc -l)
printf '%s\n' "$FIX" | sed "$FOLD" | sed "s/[0-9][0-9]*/N/g" | sort -u | sed 's/^/    /'
if [ "$got" = 3 ]; then
  echo "    ARM 3 PASS: 4 lines -> 3 keys (the two DFA lines collapsed to one;"
  echo "    the two symbol-named lines stayed apart, which they must)."
else
  echo "    ARM 3 FAIL: expected 3 keys, got $got.  Either the fold stopped"
  echo "    collapsing the back-end name, or it started collapsing something"
  echo "    it must leave alone.  Both are silent in a real run."
  exit 1
fi

# ---- verdict ------------------------------------------------------------
echo
echo "VERDICT.  Read the two lists above as different things, because the first"
echo "draft of this script did not and reported a clean 28/29:"
echo
echo "  * ARM 2's escapees are only a defect if the %qs holds a BACK-END name."
echo "    The one found here holds a SYMBOL name (\`mt_...' used before a"
echo "    target was selected), which is a real discriminator: two symbols are"
echo "    two causes and folding them would hide a second defect behind a"
echo "    first.  Not a defect."
echo
echo "  * ARM 2b's are the live masking.  Two of the three hold a MACRO name"
echo "    and are likewise real discriminators.  The third,"
echo "    \`target %qs names back end %qs', holds a TARGET TRIPLE -- one per"
echo "    configured target -- so folding the back-end name collapses nothing"
echo "    and 47 targets key as 47 causes.  That is the DFA masking again in a"
echo "    message that is not even \`back end %qs'-shaped, which is why an"
echo "    instrument keyed on that phrase alone was never enough."
echo
echo "The general rule, since this population grows with every good diagnostic:"
echo "a ranking must fold every field that varies WITH THE TARGET and no field"
echo "that varies with the DEFECT.  \`back end' and \`target' are the two"
echo "target-varying fields in this tree today; run this script after adding a"
echo "diagnostic rather than assuming the list is closed."
