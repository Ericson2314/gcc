#!/bin/sh
# WHO USES A LEAKED <cpu>-opts.h MACRO, AND FROM WHERE.
#
# Three populations, and they need different fixes:
#
#   OWN     used inside the back end that defines it.  Correct, and must keep
#           working.
#   FOREIGN used inside a DIFFERENT back end.  Either that back end defines
#           the name itself (see mtO-optsquiet.sh for whether its own answer
#           wins) or it is reading somebody else's macro outright.
#   SHARED  used outside gcc/config/ entirely -- middle end, generators, the
#           driver.  Shared code has no target, so every one of these is the
#           union answering for everyone.
#
# usage: mtO-optsuse.sh <gcc-srcdir> <leaks.txt>
set -e
S=${1:?gcc srcdir}
L=${2:?leaks list}
[ -s "$L" ] || { echo "FATAL: $L is empty"; exit 9; }

while IFS='	' read -r cpu kind m; do
  # Uses, not definitions: drop the lines that are the #define/#undef/#ifdef.
  hits=$(grep -rlw "$m" "$S" --exclude-dir=testsuite --exclude-dir=.git || true)
  for f in $hits; do
    r=${f#"$S"/}
    case $r in
      config/"$cpu"/*) w=OWN ;;
      config/*)        w=FOREIGN ;;
      *)               w=SHARED ;;
    esac
    # does this file do anything but define/undef/guard the name?
    if grep -w "$m" "$f" | grep -qv '^[ 	]*#[ 	]*\(define\|undef\|ifndef\|ifdef\|if\|elif\|endif\)'; then
      printf '%s\t%s\t%s\t%s\n' "$w" "$m" "$cpu" "$r"
    fi
  done
done < "$L"
