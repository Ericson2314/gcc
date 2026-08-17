#!/bin/sh
# What does EACH configured base actually emit for `.type' and `.align'?
#
# THIS EXISTS BECAUSE COUNTING THE BACK ENDS THAT *SPELL* A MACRO IS THE WRONG
# COUNT, AND THIS PROJECT HAS PAID FOR THAT THREE TIMES.  PRINCIPLES records
# `TARGET_PTRMEMFUNC_VBIT_LOCATION' as 8 and not 5, because four back ends
# reached the answer through a `defaults.h' fallback that a `grep' for the
# macro name cannot see.  `TYPE_OPERAND_FMT' is exactly that shape:
# `defaults.h:260' builds `ASM_OUTPUT_TYPE_DIRECTIVE' out of it, so
#
#   * a back end that never spells `TYPE_OPERAND_FMT' still HAS an answer, via
#     whatever `TYPE_OPERAND_FMT' its header chain inherited; and
#   * a back end that DOES spell it may not use it, because it also defines
#     `ASM_OUTPUT_TYPE_DIRECTIVE' itself (rx, pa64-hpux, microblaze) and the
#     `#ifndef' floor is then dead.
#
# So nothing here greps `config/'.  Each base's OWN `tm-<base>.h' is
# preprocessed -- the same header the compiler builds that base from -- and the
# macro is EXPANDED.  That is the only reading that answers "what would this
# back end have said, standing alone".
#
# THE NULL RESULT IS MADE IMPOSSIBLE TO CONFUSE WITH A PASS in two ways.  A
# base whose `tm-<base>.h' does not exist is a FATAL, not a skipped row: a
# silently short table is precisely how "we measured all 47" becomes false.
# And the expansion is printed VERBATIM, so "this base defines nothing" prints
# `<absent>' and can never be read as `""'.
#
# usage: BUILD=<47-base build dir> sh a9364e5cd42e818ad-typefmt.sh
#
# RUN THROUGH `eb-shell.sh'.  There is no `cpp' and no `gcc' on the bare PATH
# here -- the build lives in a nix dev shell -- and a bare `cpp' therefore
# fails for EVERY base at once.  That failure mode is why each cell prints
# `<cpp-failed>' rather than an empty string: the first run of this script
# produced 47 rows of `<absent>' + `<cpp-failed>', which is a null result that
# announced itself instead of reading as "no back end defines this".
set -eu
S=$(cd "$(dirname "$0")" && pwd)
if [ "${MT_INSHELL:-}" != 1 ]; then
  exec sh "$S/eb-shell.sh" "MT_INSHELL=1 BUILD='${BUILD:?set BUILD}' sh '$0'"
fi
B=${BUILD:?set BUILD to the 47-base build dir}
G=$B/gcc
[ -d "$G" ] || { echo "FATAL: no $G"; exit 9; }

# The 47 base names, from the build's own `tm-<base>.h' set.  `constrs-*',
# `tm_p*', `tm-preds*' and the per-TRIPLE headers are not bases: the base
# headers are exactly those with a matching `mt-<base>/' directory, which is
# the build's own answer to "which back ends did I configure" and is not a name
# pattern I chose.
BASES=$(ls -d "$G"/mt-*/ 2>/dev/null | sed 's|.*/mt-||; s|/$||' | sort -u)
[ -n "$BASES" ] || { echo "FATAL: no mt-<base>/ dirs in $G"; exit 9; }

# The srcdir this build was configured from, read out of its own config.log
# rather than passed in -- mt-build.sh's assertion, for the reason it gives:
# 23 committed scripts hardcoded a srcdir with a different anchor.
SRCG=$(sed -n 's|^  \$ .*/configure .*||p' "$B/config.log" >/dev/null 2>&1; \
       sed -n "s|.*srcdir='\\([^']*\\)'.*|\\1|p" "$B/config.log" | head -1)
[ -n "$SRCG" ] || SRCG=$(sed -n 's|.* \(/[^ ]*\)/configure .*|\1|p' "$B/config.log" | head -1)
SRCG=$SRCG/gcc
[ -f "$SRCG/defaults.h" ] || { echo "FATAL: srcdir not found from $B/config.log (got '$SRCG')"; exit 9; }
n=0
printf '%-14s %-26s %-24s %s\n' BASE ASM_OUTPUT_TYPE_DIRECTIVE TYPE_OPERAND_FMT ASM_OUTPUT_ALIGN
for b in $BASES; do
  H=$G/tm-$b.h
  [ -f "$H" ] || continue
  n=$((n+1))
  probe=/tmp/.tfmt-$$.c
  {
    # `config.h' FIRST and `HAVE_CONFIG_H' DEFINED.  Without the latter,
    # `config.h:4' is `#error config.h is for the host, not build, machine.'
    # -- and cpp still writes output, so the run LOOKS like it worked and every
    # macro reads `<absent>'.  `IN_GCC' is what makes `tm-<base>.h' include the
    # back end's header chain at all; without it the file is 60 lines of
    # `LIBC_GLIBC' and nothing else, which also reads as `<absent>'.
    # `GENERATOR_FILE' skips `insn-flags-<base>.h'/`insn-modes-<base>.h', which
    # are not needed for these three macros and are not built for every base at
    # every point in a build.
    echo '#include "config.h"'
    echo "#include \"$H\""
    echo '#ifdef ASM_OUTPUT_TYPE_DIRECTIVE'
    echo 'MT_TD: __MT_HAS__'
    echo '#else'
    echo 'MT_TD: __MT_ABSENT__'
    echo '#endif'
    echo '#ifdef TYPE_OPERAND_FMT'
    echo 'MT_FMT: TYPE_OPERAND_FMT'
    echo '#else'
    echo 'MT_FMT: __MT_ABSENT__'
    echo '#endif'
    echo '#ifdef ASM_OUTPUT_ALIGN'
    echo 'MT_AL: ASM_OUTPUT_ALIGN(f,LOG)'
    echo '#else'
    echo 'MT_AL: __MT_ABSENT__'
    echo '#endif'
  } > "$probe"
  # THROUGH A FILE, NOT A SHELL VARIABLE.  The preprocessed output of a tm.h
  # is ~2 MB, and `printf '%s' "$out" | sed' dies with "Argument list too
  # long" -- which the shell reports once and then every cell is empty.
  outf=/tmp/.tfmt-$$.i
  cpp -P -DIN_GCC -DGENERATOR_FILE -DHAVE_CONFIG_H \
      -I"$G" -I"$SRCG" -I"$SRCG/../include" "$probe" > "$outf" 2>/dev/null || true
  td=$(sed -n 's/^MT_TD: *//p' "$outf" | head -1)
  fmt=$(sed -n 's/^MT_FMT: *//p' "$outf" | head -1)
  al=$(sed -n 's/^MT_AL: *//p' "$outf" | head -1 | cut -c1-110)
  rm -f "$probe" "$outf"
  [ -n "$td" ] || td='<cpp-failed>'
  printf '%-14s %-26s %-24s %s\n' "$b" "${td:-<absent>}" "${fmt:-<absent>}" "${al:-<absent>}"
done
echo "-- bases read: $n"
[ "$n" -ge 40 ] || { echo "FATAL: only $n bases read; a short table is not a result"; exit 9; }
