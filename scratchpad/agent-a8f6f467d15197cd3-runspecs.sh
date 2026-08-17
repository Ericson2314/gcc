#!/bin/sh
# agent-a8f6f467d15197cd3-runspecs.sh -- run a7ee6ca7c923e4a58-specsN.sh over
# the 45 targets that have a VERIFIED cross assembler, reading the target list
# from the build dir's OWN config.log rather than from a checked-in file.
#
# WHY FROM config.log.  The canonical triple is what names the per-target
# directory and the `specs-config', and it is NOT what was typed on the
# command line -- `config.sub' rewrites `s390x-linux-gnu' to
# `s390x-ibm-linux-gnu', `tic6x' appears where `c6x-elf' went in, and so on.
# The build's own `--enable-backends=' line is the authority for what this
# build dir actually contains.  (It also carries a trailing shell quote on the
# last entry, which produced `xtensa-unknown-elf'' -- a target with no
# assembler, i.e. a manufactured NO-CROSS-AS.  Stripped, and asserted below.)
#
# amdgcn and nvptx are excluded BY NAME, never by "no assembler found":
# INSTRUMENTS.md's three verdicts must not be collapsed, and defaulting a
# missing cross `as' to the host's is worth ~10,000 wrong results per target.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to a tools dir with a bin/ of <triple>-as}

sed -n "s/.*--enable-backends=\([^ ]*\).*/\1/p" "$B/config.log" | head -1 \
  | tr ',' '\n' | tr -d "'\"" | sort -u > "$B/canon-all.txt"
NALL=$(grep -c . "$B/canon-all.txt")
[ "$NALL" = 47 ] || { echo "FATAL: config.log names $NALL back ends, expected 47"; exit 9; }
grep -vE '^(amdgcn-unknown-amdhsa|nvptx-unknown-none)$' "$B/canon-all.txt" > "$B/canon-45.txt"
N=$(grep -c . "$B/canon-45.txt")
[ "$N" = 45 ] || { echo "FATAL: $N targets after excluding amdgcn+nvptx, expected 45"; exit 9; }

# EVERY one must have a cross `as' that EXECUTES.  Not "a path exists" --
# a dangling symlink is the shape that silently becomes the host `as'.
miss=0
while read -r t; do
  "$TOOLS/bin/$t-as" --version > /dev/null 2>&1 || { echo "NO WORKING as: $t"; miss=$((miss + 1)); }
done < "$B/canon-45.txt"
[ "$miss" = 0 ] || { echo "FATAL: $miss of $N targets have no working cross as"; exit 9; }
echo "45 targets, all with a cross \`as' that executed; amdgcn+nvptx excluded by name"

B="$B" TOOLS="$TOOLS" sh "$S/a7ee6ca7c923e4a58-specsN.sh" $(cat "$B/canon-45.txt")
