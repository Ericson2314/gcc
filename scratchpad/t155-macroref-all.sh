#!/bin/sh
# #155 -- run t155-macroref.sh over every name currently in the rename list.
#
# This is the arm that would have caught `constant_address_p' and
# `legitimate_pic_operand_p' before the build rather than after it.
set -u
S=$(cd "$(dirname "$0")" && pwd)
M=$(cd "$S/../gcc" && pwd)/Makefile.in
awk '/^MULTI_TARGET_RENAME_NAMES = /,/[^\\]$/' "$M" \
  | sed 's/^MULTI_TARGET_RENAME_NAMES = //; s/\\$//' \
  | tr -s ' \t' '\n' | grep . > /tmp/t155-renames.txt
n=$(grep -c . /tmp/t155-renames.txt)
[ "$n" -gt 5 ] || { echo "REFUSING TO SCORE: parsed only $n names"; exit 9; }
echo "checking $n names in MULTI_TARGET_RENAME_NAMES"
sh "$S/t155-macroref.sh" $(cat /tmp/t155-renames.txt)
