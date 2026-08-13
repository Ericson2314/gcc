#!/bin/sh
# NEGATIVE CONTROL for the --enable-targets -> --enable-backends mapping.
#
# mtN-conf.sh passes ONLY --enable-targets and its `make configure-gcc' must
# succeed.  That is worth nothing unless the same invocation FAILS BY NAME
# when the mapping is absent -- a green from an arm that cannot go red is the
# shape this project has produced 26+ times.
#
# So this runs gcc/configure directly with the same host flags and NO
# --enable-backends, and REFUSES unless it fails with the specific message.
# It asserts the message, not merely a nonzero exit: gcc/configure can exit 1
# for a hundred unrelated reasons and any of them would score as a pass.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b-a0e67dff8d4a6fbbd-nomap}
rm -rf "$D"; mkdir -p "$D"
# --build/--host/--target are spelled out because gcc/configure refuses with
# "*** Configuration not supported" long before it reaches the backends check
# when they are unset, and that failure would score as a pass for an arm that
# only tested the exit status.
sh "$S/eb-shell.sh" "cd $D && $SRC/gcc/configure --disable-werror \
  --disable-nls --enable-languages=c,lto \
  --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu \
  --target=x86_64-pc-linux-gnu \
  CC=gcc CXX=g++" > "$D/out" 2>&1 || true
if grep 'enable-backends=LIST is required' "$D/out" > /dev/null; then
  echo "CONTROL FIRED: gcc/configure without --enable-backends fails by name"
  exit 0
fi
echo "CONTROL DID NOT FIRE -- the arm in mtN-conf.sh proves nothing."
tail -5 "$D/out"
exit 9
