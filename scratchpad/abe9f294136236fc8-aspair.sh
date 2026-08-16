#!/bin/sh
# Alias a built cross toolchain under the CANONICAL gcc triple, by explicit pair.
#
# WHY EXPLICIT PAIRS RATHER THAN `config.sub'.  Two different renamings are in
# play and only one of them is `config.sub''s:
#
#   1. CANONICALISATION.  `backends-47.txt' says `s390x-linux-gnu' and gcc
#      names everything afterwards `s390x-ibm-linux-gnu'.  `config.sub' does
#      that one.
#   2. RESPELLING.  nixpkgs' `lib.systems' cannot parse `arm-eabi' or
#      `arc-elf32' at all, so the assembler has to be requested as
#      `arm-none-eabi' / `arc-none-elf' -- a DIFFERENT SPELLING OF THE SAME
#      TARGET, recorded in `a7ee6ca7c923e4a58-astry2.sh'.  `config.sub' knows
#      nothing about that, because it is nixpkgs' vocabulary, not gcc's.
#
# Composing the two is where a wrong answer would come from, so each pair is
# written out and PRINTED, and the same file records that
# `a7ee6ca7c923e4a58-astry2.sh' once offered `powerpc64le-*' as a respelling of
# `powerpc64-*' -- the OTHER ENDIANNESS installed under a big-endian name,
# which is this project's root bug inside the tooling meant to prevent it.
# Every pair below is the same architecture and the same endianness; where a
# family member rather than an exact match is used, say so in the report.
#
# usage: abe9f294136236fc8-aspair.sh <toolsbin> <built>=<canonical>...
set -u
BIN=${1:?tools bin dir}; shift
[ $# -ge 1 ] || { echo "FATAL: name at least one <built>=<canonical> pair"; exit 9; }
nok=0; nbad=0
for p in "$@"; do
  src=${p%%=*}; dst=${p#*=}
  [ "$src" != "$p" ] || { echo "FATAL: '$p' is not <built>=<canonical>"; exit 9; }
  if [ ! -x "$BIN/$src-as" ]; then
    printf '%-24s -> %-28s NO SOURCE\n' "$src" "$dst"; nbad=$((nbad+1)); continue
  fi
  for tool in as ld nm ar ranlib objdump objcopy strip readelf; do
    [ -e "$BIN/$src-$tool" ] || continue
    ln -sf "$(readlink -f "$BIN/$src-$tool")" "$BIN/$dst-$tool"
  done
  # EXISTENCE IS NOT EXECUTION -- the whole reason GUARD 3c exists.
  v=$("$BIN/$dst-as" --version 2>&1 | head -1)
  case "$v" in
    *"GNU assembler"*) printf '%-24s -> %-28s OK  %s\n' "$src" "$dst" "$v"; nok=$((nok+1)) ;;
    *) printf '%-24s -> %-28s BROKEN: %s\n' "$src" "$dst" "$v"; nbad=$((nbad+1)) ;;
  esac
done
echo "-- $nok aliased and runnable, $nbad failed, of $#"
[ "$nbad" = 0 ] || exit 9
