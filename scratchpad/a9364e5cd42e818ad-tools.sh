#!/bin/sh
# The five cross assemblers this task measures with, ASSERTED BY EXECUTION.
#
# Symlinks into two existing tools dirs -- a5764a65f9eec0063's four LP64 targets
# and a660907426e03e4e9's arm -- rather than a fresh nixpkgs materialisation,
# because they are symlinks into the nix store and cost nothing.  What is NOT
# borrowed is the PATH: INSTRUMENTS.md records `a5764a65f9eec0063-score.sh'
# hardcoding another worktree's tools as "GUARD 3c's own failure mode wearing a
# harness's clothes".  Here the dir is this worktree's, named for it, and every
# assembler in it is RUN -- `--version' printing its own target -- rather than
# merely stat'ed.  A present-but-broken `as' and an absent one are different
# failures and only execution tells them apart.
set -eu
T=/tmp/tools-agent-a9364e5cd42e818ad
n=0
for t in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu \
	 s390x-ibm-linux-gnu arm-unknown-linux-gnueabihf; do
  AS=$T/bin/$t-as
  [ -x "$AS" ] || { echo "FATAL: $AS is not executable"; exit 9; }
  v=$("$AS" --version 2>&1 | head -1) || { echo "FATAL: $AS did not RUN"; exit 9; }
  case "$v" in
    *"GNU assembler"*) ;;
    *) echo "FATAL: $AS ran but did not identify as GNU as: $v"; exit 9 ;;
  esac
  # And it must be the assembler FOR THAT TARGET, not a rename of the host's.
  # A rename passes every name-based check there is; assembling a directive the
  # host accepts and the target does not is exactly the trap this task is about.
  echo 'int' > /tmp/.tt-$$.s 2>/dev/null || true
  printf '\t.text\n' > /tmp/.tt-$$.s
  "$AS" -o /tmp/.tt-$$.o /tmp/.tt-$$.s 2>/dev/null || { echo "FATAL: $AS cannot assemble an empty .text"; exit 9; }
  m=$("$T/bin/$t-readelf" -h /tmp/.tt-$$.o 2>/dev/null | sed -n 's/.*Machine: *//p')
  rm -f /tmp/.tt-$$.s /tmp/.tt-$$.o
  printf '%-32s %s   Machine: %s\n' "$t" "$v" "${m:-<unreadable>}"
  n=$((n+1))
  [ -f "$T/$t.hdr" ] || { echo "FATAL: no $T/$t.hdr"; exit 9; }
  [ -d "$(cat "$T/$t.hdr")" ] || { echo "FATAL: headers named by $t.hdr do not exist"; exit 9; }
done
[ "$n" = 4 ] || { echo "FATAL: $n cross targets, not 4"; exit 9; }
echo "-- 4 cross assemblers EXECUTED (x86_64 is the host's own), headers present"
