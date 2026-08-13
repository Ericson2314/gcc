#!/bin/sh
# #51: classify the six bare names the primary's insn-emit answers for everyone.
#
# The question that decides whether a uniform forwarder can be written is
# "does EVERY configured base define this name in its own namespace?", and it
# has to be asked of the objects, not of the .md files: several of these names
# are produced by a mode/code iterator and never appear literally in any .md
# (gen_movxf is one -- `"movxf"' occurs in ia64.md and m68k.md only, yet i386
# defines gen_movxf through <MODEF>).  Grepping the machine descriptions would
# have given the wrong answer for exactly the name the ruling is about.
#
# Also reports WHO defines the bare name, so that "the primary answers for
# everyone" is measured rather than asserted.
set -u -o pipefail
D=${D:-/tmp/b78}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
G=$D/gcc
[ -d "$G" ] || { echo "FATAL: no $G"; exit 9; }

nix-shell -I "nixpkgs=$NP" -p binutils coreutils --substituters 'https://cache.nixos.org/' --run '
set -u -o pipefail
cd '"$G"' || exit 9
BASES="i386 aarch64"
NAMES="add_clobbers added_clobbers_hard_reg_p gen_blockage gen_nop gen_speculation_barrier gen_movxf"

# Non-vacuity: a name that NO base defines would look identical to a broken
# instrument, so assert first that the instrument sees a name we know is there.
probe=$(nm --defined-only insn-recog-i386-*.o 2>/dev/null | c++filt | grep -c "insn_i386::recog(") || true
[ "${probe:-0}" -ge 1 ] || { echo "FATAL: instrument cannot even see insn_i386::recog -- every 0 below would be meaningless"; exit 9; }
echo "instrument check: insn_i386::recog visible ($probe)"
echo

printf "%-30s %-22s %s\n" NAME "per-base definitions" "bare (global) definition in"
for n in $NAMES; do
  line=""
  for b in $BASES; do
    c=$(nm --defined-only insn-*-$b-*.o insn-*-$b.o 2>/dev/null | awk "\$2 ~ /^[TWD]\$/ {print \$3}" \
        | c++filt | grep -c "^insn_$b::$n(") || true
    line="$line $b=${c:-0}"
  done
  # Who defines the BARE name.
  #
  # NOT grep -q.  Under set -o pipefail, a grep -q that MATCHES kills the rest
  # of the pipeline with SIGPIPE, the pipeline status becomes 141, and the &&
  # then treats a match as a miss -- so every one of these read <none> on the
  # first run, including names another script had already found here.  A false
  # negative produced by the shell option, not by the data.
  # (This comment is written without apostrophes on purpose: the whole body is
  # inside a single-quoted nix-shell --run, and one apostrophe ends the quote.)
  who=$(for o in $(find . -name "*.o"); do
          c=$(nm --defined-only "$o" 2>/dev/null | awk "\$2 ~ /^[TWD]\$/ {print \$3}" | c++filt \
              | grep -c "^$n(") || true
          [ "${c:-0}" -ge 1 ] && echo "$o"
        done | tr "\n" " ")
  printf "%-30s %-22s %s\n" "$n" "$line" "${who:-<none>}"
done
'
