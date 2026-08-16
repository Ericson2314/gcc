#!/bin/sh
# Run `target-specs' for EVERY configured target, not the hardcoded four.
#
# taa-specs.sh serves exactly {x86_64, aarch64, riscv64, s390x} with each
# target's glibc headers written into the command.  This is the N-target form,
# driven by the OK rows of a7ee6ca7c923e4a58-astry.sh.
#
# TWO THINGS DELIBERATELY NOT DONE, because both would manufacture a green:
#
#  * NO HOST-`as' FALLBACK.  taa-fallback-specs.sh points target-specs at the
#    BUILD MACHINE's `as' when a cross one is missing, and #113b measured what
#    that writes: a file that NAMES the target while DESCRIBING x86_64, 95 of
#    101 lines identical, every name- and path-based check green.  Here a
#    target with no cross assembler is recorded as NO-CROSS-AS and its specs
#    are generated with the target's own built-in defaults only -- an honestly
#    weaker artefact, labelled as such, rather than another target's answer
#    wearing its name.
#
#  * NO SHARED HEADER DIRECTORY.  A single glibc include dir handed to every
#    target is one machine's answer served to all of them (PRINCIPLES 2), and
#    for the bare-metal ELF targets here it would be actively wrong.  The
#    compile-only / scan-assembler axis needs no libc, so the flag is simply
#    omitted where the target has no headers of its own, and which targets
#    those are is PRINTED rather than assumed.
#
# usage: B=<builddir> TOOLS=<astry outdir> a7ee6ca7c923e4a58-specsN.sh <triple>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to an astry output dir}
[ $# -ge 1 ] || { echo "FATAL: name at least one target"; exit 9; }
[ -d "$B/gcc" ] || { echo "FATAL: no $B/gcc"; exit 9; }

VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }

# `-k' IS LOAD-BEARING, NOT A CONVENIENCE.  Without it make stops at the first
# target whose probe fails, and EVERY LATER TARGET IS NEVER ATTEMPTED -- which
# in the report is indistinguishable from "it was tried and produced nothing".
# Measured: `m68k-unknown-elf' failed an affirmative arm and seven targets
# behind it were silently never reached, read off as seven ABSENT specs.
# PRINCIPLES: under `-k', "never attempted" and "passed" are the same silence,
# so ABSENT below is reported per target and never summed into a verdict.
cmds="cd $B/gcc && make multi-target-specs && cd $B"
nas=0; nno=0
for T in "$@"; do
  if [ -x "$TOOLS/bin/$T-as" ]; then
    cmds="$cmds; make -k configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS/bin"
    nas=$((nas+1))
  else
    cmds="$cmds; make -k configure-target-specs-$T"
    nno=$((nno+1))
  fi
done
echo "== $# targets: $nas with a real cross as, $nno WITHOUT (NO-CROSS-AS)"

# NO `set -e' HERE.  With it, the first failing target aborts the whole shell
# and undoes the `-k' above -- the two guards would cancel out and the result
# would look exactly like the failure `-k' was added to remove.
sh "$S/eb-shell.sh" "PATH=$TOOLS/bin:\$PATH; export PATH; $cmds" \
  > "$B/specsN.out" 2> "$B/specsN.err"
echo "specs rc=$?"

# THE ARTEFACT, NOT THE EXIT STATUS.  target-specs has exited 1 for every
# target while leaving specs files TRUNCATED at 39 of 101 lines, and every
# guard passed because 39 lines is non-empty (PRINCIPLES 4).  So each file is
# reported with its line count AND its md5, and the md5s are checked for
# COINCIDENCE below: two targets with identical specs is the host-`as'
# fallback's signature.
echo "-- specs-config per target:"
: > /tmp/specsN-md5-$$
nok=0
for T in "$@"; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ -f "$F" ]; then
    m=$(md5sum < "$F" | cut -c1-12)
    printf '  %-28s wc -l %-5s grep -c . %-5s md5 %s%s\n' "$T" \
      "$(wc -l < "$F")" "$(grep -c . "$F")" "$m" \
      "$([ -x "$TOOLS/bin/$T-as" ] || echo '   NO-CROSS-AS')"
    echo "$m $T" >> /tmp/specsN-md5-$$
    nok=$((nok+1))
  else
    printf '  %-28s ABSENT\n' "$T"
  fi
done
echo "-- $nok of $# have a specs-config"
echo "-- DUPLICATE md5s (two targets described identically -- the fallback's signature):"
sort /tmp/specsN-md5-$$ | awk '{print $1}' | uniq -d | grep . || echo "  none"
rm -f /tmp/specsN-md5-$$
