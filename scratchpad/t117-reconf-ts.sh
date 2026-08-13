#!/bin/sh
# TASK #117 -- regenerate target-specs/configure from configure.ac.
#
# WHY THIS IS CHECKED RATHER THAN ASSUMED.  `target-specs/configure.ac' emits
# the whole capability list from an UNQUOTED heredoc, and a single backtick in
# the wrong place there has already silently swallowed all 97 keys and exited
# 0 (PRINCIPLES 5).  So this script does not trust autoconf's exit status: it
# asserts, in the GENERATED file, that the key added here is present AND that
# keys emitted both before and after it survived.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a75a2f51f92af9802

nix-shell -I "nixpkgs=$NP" -p autoconf269 gnum4 \
  --substituters 'https://cache.nixos.org/' \
  --run "cd $SRC/target-specs && autoconf -o configure configure.ac" || exit $?

C="$SRC/target-specs/configure"
[ -s "$C" ] || { echo "FATAL: configure is empty or missing"; exit 9; }

# 1. The subject.  It must appear BOTH in the emitter and in ts_expected.
n_emit=$(grep -c '^as_ltoffx_ldxmov_relocs ' "$C")
n_exp=$(grep -c 'as_alpha_jsrdirect_relocs as_ltoffx_ldxmov_relocs' "$C")
echo "emitter line for as_ltoffx_ldxmov_relocs : $n_emit  (want 1)"
echo "ts_expected mentions it                  : $n_exp   (want 1)"

# 2. Heredoc survival controls: keys emitted BEFORE and AFTER the subject.
#    If the heredoc had been swallowed these would be gone too, and the
#    subject's own presence would not have told us.
for k in as_alpha_explicit_relocs as_s390_architecture_modifiers solaris_ld \
         native_system_header_component; do
  c=$(grep -c "^$k " "$C")
  echo "control emitter line $k : $c  (want 1)"
  [ "$c" -eq 1 ] || { echo "FATAL: control key $k lost -- heredoc damaged"; exit 9; }
done

[ "$n_emit" -eq 1 ] || { echo "FATAL: subject not emitted"; exit 9; }
[ "$n_exp" -eq 1 ] || { echo "FATAL: subject not in ts_expected"; exit 9; }
echo "t117-reconf-ts: OK"
