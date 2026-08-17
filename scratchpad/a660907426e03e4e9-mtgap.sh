#!/bin/sh
# THE GENERAL FORM OF THE TIP BREAKAGE, ASKED OF EVERY `mt_*' NAME AT ONCE.
#
# `make all-gcc' at `3f75b7f16a3' dies on ONE undeclared name, so the build
# reports the FIRST gap and stops.  "One error" and "eleven errors of which the
# compiler printed one" are the same output, and fixing only the named one is
# the half-fix shape.  So enumerate: every `mt_*' identifier CALLED in shared
# code, against every `mt_*' identifier DECLARED anywhere in gcc/.
#
# A name reported here is a CANDIDATE, not a verdict -- a call inside a comment
# or a name declared in a generated header would both show up wrongly.  The
# compiler gives the verdict; this only says where to look and, crucially,
# whether the answer is one name or twenty.
set -u
cd "$(dirname "$0")/.." || exit 9
T=$(mktemp -d) || exit 9
trap 'rm -rf "$T"' 0
# CALLED: `mt_foo (' at a use site.  Comments are stripped first -- this
# branch's conversion notes name these functions constantly in prose, and
# INSTRUMENTS.md records a scan that scored 73 of 94 wrong for exactly that.
#
# AND THE WORD BOUNDARY IS LOAD-BEARING, MEASURED: without `\b' the pattern
# `mt_[a-z0-9_]*(' matches the TAIL of `gimple_stmt_p (', `stmt_may_clobber_
# ref_p (' and every other `*stmt_*' call in the middle end.  The first run of
# this script reported **255 called-but-undeclared names**, of which the real
# count is a handful; the rest were `mt_p', `mt_operands', `mt_1' ... i.e.
# substrings.  A scan that flags everything has a perfect positive arm and is
# worthless -- INSTRUMENTS.md's own rule, reproduced here within the hour.
# `testsuite/' is excluded for the same reason: it is not shared compiler code.
find gcc -path gcc/testsuite -prune -o \( -name '*.cc' -o -name '*.h' \) -print | while read -r f; do
  sed -e 's://.*::' "$f" | grep -oE '\bmt_[a-z0-9_]*[ ]*\(' \
    | sed -e 's/[ ]*($//' -e 's/[ ]*(//' | sed "s|\$|	$f|"
done | sort -u > "$T/used"
# DECLARED or DEFINED: `extern ... mt_foo (void);' or a definition line.
#
# NOT `(void)' ONLY.  The first version matched `extern bool mt_foo (void);'
# and nothing else, so every accessor that TAKES AN ARGUMENT -- and most of the
# converted predicates do (`mt_constant_address_p (machine_mode, rtx)') --
# looked undeclared.  That over-report is the same failure as the missing word
# boundary above, one layer along: a scan whose DENOMINATOR is too small flags
# correct code, and a false RED costs what a false green costs.
grep -rhE 'extern .*\bmt_[a-z0-9_]+[ ]*\(' gcc --include='*.h' \
  | grep -oE '\bmt_[a-z0-9_]+[ ]*\(' | sed 's/[ ]*(//' | sort -u > "$T/decl"
# A DEFINITION IS A DECLARATION.  GCC's house style puts the function name in
# column 1 on its own line, in HEADERS as well as `.cc' files -- `addresses.h'
# defines `mt_constant_address_p' `static inline' that way, and
# `target-cumargs.h' does the same for `mt_pack_cumulative_args'.  Restricting
# this arm to `*.cc' reported both as undeclared.
grep -rhoE '^mt_[a-z0-9_]+ *\(' gcc --include='*.cc' --include='*.h' \
  | sed 's/ *($//;s/ *(//' | sort -u >> "$T/decl"
sort -u "$T/decl" -o "$T/decl"
cut -f1 "$T/used" | sort -u > "$T/usednames"
echo "-- mt_* names CALLED: $(grep -c . "$T/usednames")   DECLARED/DEFINED: $(grep -c . "$T/decl")"
comm -23 "$T/usednames" "$T/decl" > "$T/gap"
n=$(grep -c . "$T/gap" || true)
# NON-VACUITY: this instrument's own null result must not read as a pass.  If
# it found no calls at all, the sed/grep pipeline broke and "no gaps" means
# "nothing was examined".
[ "$(grep -c . "$T/usednames")" -gt 20 ] \
  || { echo "FATAL: only $(grep -c . "$T/usednames") mt_* calls found; the scan did not run"; exit 9; }
if [ "$n" = 0 ]; then
  echo "MTGAP: 0 called-but-undeclared mt_* names."
  exit 0
fi
echo "MTGAP: $n called-but-undeclared mt_* names -- each is a build stop:"
while read -r nm; do
  printf '  %-38s called at: %s\n' "$nm" \
    "$(awk -F'\t' -v n="$nm" '$1==n {printf "%s ", $2}' "$T/used")"
done < "$T/gap"
exit 1
