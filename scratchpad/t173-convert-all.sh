#!/bin/sh
# #173 -- convert every plain per-back-end stem include under gcc/config to
# BASE_HEADER, EXCLUDING the 15 files that are compiled once and have no base.
#
# `tm.h' is only one of sixteen stems the deleted `-I<base>-inc' was serving;
# converting it alone and then deleting the -I would have left the other
# fifteen silently reading the build root's copies, which for nine of them is
# the primary back end's header.  See T173-BASE-HEADER.md.
set -e
S=$(cd "$(dirname "$0")" && pwd)
cd "$S/.."
sh "$S/t173-sites.sh" > /dev/null   # writes /tmp/t173-kindb.txt
for s in tm tm_p tm-preds tm-constrs options insn-constants insn-attr \
	 insn-attr-common insn-codes insn-config insn-flags insn-modes \
	 insn-modes-inline insn-opinit insn-recog insn-target-def; do
  git grep -l "^#include \"$s\.h\"" -- gcc/config | sort > /tmp/t173-s.txt
  comm -23 /tmp/t173-s.txt /tmp/t173-kindb.txt > /tmp/t173-do.txt
  [ -s /tmp/t173-do.txt ] || continue
  sh "$S/t173-convert.sh" "$s" < /tmp/t173-do.txt
done
