#!/bin/sh
# TASK #111 -- ARM D CONFIRMATION AGAINST THE REAL PREPROCESSOR.
#
# t111-armD2.sh is a TEXT sweep of the source.  This is the same question asked
# of the actual build: preprocess a TU with EXACTLY the flags emit-rtl.o is
# compiled with (a genuinely shared middle-end TU), dump the macro table, and
# ask which of the population is actually defined there.
#
# It exists because the text sweep can be wrong in both directions:
#   * FALSE POSITIVE -- a macro i386 does not spell may still arrive from a
#     header i386.h includes (elfos.h, gnu-user.h, linux.h, defaults.h ...),
#     in which case there is no absence and nothing to fix.
#   * FALSE NEGATIVE -- a macro i386.h spells inside an #if it does not take.
# Neither is visible to grep.  PRINCIPLES 4 rule 4: confirm a result by finding
# the thing under another name.
set -u
D=${D:-/tmp/b112}
G=${G:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315/gcc}
A=${A:-/tmp/t112-armD2}
O=${O:-/tmp/t112-verify}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
rm -rf "$O"; mkdir -p "$O"
[ -s "$A/population.txt" ] || { echo "FATAL: no $A/population.txt -- run t111-armD2.sh"; exit 9; }
[ -f "$D/gcc/tm.h" ] || { echo "FATAL: no $D/gcc/tm.h"; exit 9; }

cat > "$O/probe.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
int main (void) { return 0; }
EOF

I="-I. -I$G -I$G/. -I$G/../include -I$G/../libcpp/include -I$G/../libcody -I$G/../libdecnumber -I$G/../libdecnumber/bid -I../libdecnumber -I$G/../libbacktrace"
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && g++ -E -dM -DIN_GCC -DHAVE_CONFIG_H -DMULTI_TARGET_OPTION_TABLES $I $O/probe.cc" \
  > "$O/macros-raw.txt" 2> "$O/macros.err"
rc=$?
[ "$rc" = 0 ] || { echo "FATAL: preprocess failed rc=$rc"; sed 's/^/  /' "$O/macros.err" | head -20; exit 9; }
n=$(wc -l < "$O/macros-raw.txt")
[ "$n" -gt 500 ] || { echo "FATAL: only $n macros -- probe did not really preprocess"; exit 9; }
sed -n 's/^#define \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$O/macros-raw.txt" | sort -u > "$O/defined-here.txt"

# NON-VACUITY: this instrument must be able to say YES and NO.  If every answer
# came out the same way the comparison would be meaningless.
grep -qx TARGET_64BIT "$O/defined-here.txt" \
  || { echo "FATAL: TARGET_64BIT not defined in a shared TU -- probe context wrong"; exit 9; }
grep -qx MT_THIS_MACRO_DOES_NOT_EXIST "$O/defined-here.txt" \
  && { echo "FATAL: probe says a nonexistent macro is defined"; exit 9; }

comm -12 "$A/population.txt" "$O/defined-here.txt" > "$O/present.txt"
comm -23 "$A/population.txt" "$O/defined-here.txt" > "$O/absent.txt"

echo "population:                                     $(wc -l < "$A/population.txt")"
echo "  actually DEFINED in a shared middle-end TU:   $(wc -l < "$O/present.txt")"
echo "  actually ABSENT there:                        $(wc -l < "$O/absent.txt")"
echo
# The confirmed actionable set: text sweep said SILENT+actionable, AND the real
# preprocessor confirms the macro is absent from shared code.
cut -f1 "$A/silent.txt" | sort -u > "$O/silent-names.txt"
comm -12 "$O/silent-names.txt" "$O/absent.txt" > "$O/confirmed.txt"
comm -12 "$O/silent-names.txt" "$O/present.txt" > "$O/text-false-pos.txt"
echo "text-sweep SILENT rows:                         $(wc -l < "$O/silent-names.txt")"
echo "  CONFIRMED absent by the preprocessor:         $(wc -l < "$O/confirmed.txt")"
echo "  FALSE POSITIVES (arrive via an included hdr): $(wc -l < "$O/text-false-pos.txt")"
echo
echo "=== CONFIRMED SILENT ABSENCES (macro, back ends defining it) ==="
while read -r m; do
  printf '%-36s %s\n' "$m" "$(awk -F'\t' -v m="$m" '$1==m {print "nbe=" $2}' "$A/report.txt")"
done < "$O/confirmed.txt"
echo
echo "=== text false positives, for the record ==="
cat "$O/text-false-pos.txt" | tr '\n' ' '; echo
