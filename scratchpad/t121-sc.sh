#!/bin/sh
# #121 -- stock-compare, with an ABSOLUTE IN (a relative path silently produced
# a false green once, and the negative control reported "ok, differs" while
# comparing two nonexistent files) and this task's own build dir.
#
# Why it is run at all for this task: the mode-hole fix itself cannot affect a
# stock build (holes only exist under the `-U' union numbering, and a
# single-target genmodes run creates none), but the SECOND HALF touches shared
# middle-end files -- expmed.cc and tree.cc -- so the claim "provably a no-op on
# a single-target build" needs an instrument rather than an argument.
set -u
S=$(cd "$(dirname "$0")" && pwd)
MT=${MT:-/tmp/b-abeb4d62}
exec env MT="$MT" OUT=/tmp/sc121 IN="$S/big.c" bash "$S/stock-compare.sh"
