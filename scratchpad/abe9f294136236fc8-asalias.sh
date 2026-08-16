#!/bin/sh
# Give the tools dir the CANONICAL triple names as well as the requested ones.
#
# `backends-47.txt' names targets the way the top level takes them
# (`arc-elf32', `arm-eabi', `s390x-linux-gnu'), and `config.sub' canonicalises
# each one (`arc-unknown-elf32', `arm-unknown-eabi', `s390x-ibm-linux-gnu').
# The canonical form is what names the per-target directory, the specs-config,
# the `MT_TOOLS_<triple>' variable and `$TOOLS/<triple>-as' -- INSTRUMENTS.md
# says so about `s390x' specifically -- while `asroot.sh' produced files under
# the name it was ASKED for.
#
# A missing alias is not a loud failure: `mtcheck.sh' GUARD 3c refuses that
# target and the run reports it BLOCKED, which is honest but costs the target.
# Worse would be a wrong alias, so each pair is derived by running `config.sub'
# rather than written down, and the result is PRINTED per pair.
#
# usage: abe9f294136236fc8-asalias.sh <srcdir> <toolsbin> <requested-triple>...
set -u
S=${1:?srcdir}; BIN=${2:?tools bin dir}; shift 2
[ -x "$S/config.sub" ] || { echo "FATAL: no $S/config.sub"; exit 9; }
[ $# -ge 1 ] || { echo "FATAL: name at least one triple"; exit 9; }
nnew=0; nsame=0; nmiss=0
for t in "$@"; do
  c=$(sh "$S/config.sub" "$t") || { echo "FATAL: config.sub refused $t"; exit 9; }
  if [ ! -x "$BIN/$t-as" ]; then
    printf '%-26s -> %-30s NO SOURCE (%s-as absent)\n' "$t" "$c" "$t"
    nmiss=$((nmiss+1)); continue
  fi
  if [ "$c" = "$t" ]; then
    printf '%-26s -> %-30s (canonical already)\n' "$t" "$c"
    nsame=$((nsame+1)); continue
  fi
  for tool in as ld nm ar ranlib objdump objcopy strip readelf; do
    [ -e "$BIN/$t-$tool" ] || continue
    ln -sf "$(readlink -f "$BIN/$t-$tool")" "$BIN/$c-$tool"
  done
  # IT MUST RUN UNDER THE NEW NAME.  A symlink that exists is not a tool that
  # executes, and a non-executing cross `as' is what GUARD 3c exists for.
  v=$("$BIN/$c-as" --version 2>&1 | head -1)
  case "$v" in
    *assembler*|*GNU*) printf '%-26s -> %-30s OK  %s\n' "$t" "$c" "$v" ; nnew=$((nnew+1)) ;;
    *) printf '%-26s -> %-30s BROKEN: %s\n' "$t" "$c" "$v" ; nmiss=$((nmiss+1)) ;;
  esac
done
echo "-- aliased $nnew, already canonical $nsame, missing/broken $nmiss, of $#"
[ "$nmiss" = 0 ] || exit 9
