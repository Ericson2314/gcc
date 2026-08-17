#!/bin/sh
# t243 -- acceptance for `install-fixed-headers-<triple>'.
#
# THREE ARMS, none satisfiable by absence:
#   1  two targets with DIFFERENT LIBCS get include-fixed directories whose
#      CONTENTS DIFFER.  Identical contents would mean one target's headers
#      were fixed for both, which is this branch's root defect in the install
#      tree.
#   2  a run that produces nothing FAILS LOUDLY.
#   3  NEGATIVE CONTROL: --headers pointed at a directory with no headers must
#      fail by name rather than install an empty include-fixed.
set -u
B=/home/jcericson/src/gnu/gcc/build/mt-hdr
S=/home/jcericson/src/gnu/gcc/multi-target
T1=aarch64-unknown-linux-musl
T2=armv6l-unknown-linux-gnueabihf
H1=`cat $B/tools/HEADERS-$T1`/include
H2=`cat $B/tools/HEADERS-$T2`/include
V=`cat $S/gcc/BASE-VER`
INC=$B/inst/lib/gcc/$V

sh $S/scratchpad/eb-shell.sh "cd $B && make -j24 install-gcc install-fixincludes" > $B/install.log 2>&1 \
  || { echo "FATAL: make install failed"; tail -5 $B/install.log; exit 9; }
echo "-- install ok"

echo "-- include-fixed after a PLAIN install (the defect, before this rule):"
find $INC -name include-fixed -print | sed 's/^/     /'
echo "     (nothing above = the defect reproduced)"

for t in $T1 $T2; do
  eval h=\$H`expr $t = $T1 '&' 1 '|' 2 2>/dev/null` 2>/dev/null
done

for pair in "$T1 $H1" "$T2 $H2"; do
  t=`echo $pair | cut -d' ' -f1`; h=`echo $pair | cut -d' ' -f2`
  sh $S/scratchpad/eb-shell.sh "cd $B && make configure-target-specs-$t \
      TOOLS_DIR_FOR_$t=$B/tools/bin \
      TARGET_SPECS_FLAGS_FOR_$t=--with-native-system-header-dir=$h" \
      > $B/ts-$t.log 2>&1 \
    || { echo "FATAL: configure-target-specs-$t failed"; tail -15 $B/ts-$t.log; exit 9; }
  sh $S/scratchpad/eb-shell.sh "cd $B && make install-target-specs-$t" > $B/tsi-$t.log 2>&1 \
    || { echo "FATAL: install-target-specs-$t failed"; tail -15 $B/tsi-$t.log; exit 9; }
  echo "-- $t: native_system_header_dir = `sed -n 's/^native_system_header_dir *//p' $B/mt-config/$t/specs-config 2>/dev/null || sed -n 's/^native_system_header_dir *//p' $B/*/$t/specs-config`"
done

for t in $T1 $T2; do
  sh $S/scratchpad/eb-shell.sh "cd $B && make install-fixed-headers-$t" > $B/fh-$t.log 2>&1
  echo "-- install-fixed-headers-$t rc=$?"
  tail -3 $B/fh-$t.log
done

echo "== ARM 1: contents"
for t in $T1 $T2; do
  echo "  $t: `find $INC/$t/include-fixed -type f 2>/dev/null | wc -l` files"
  (cd $INC/$t/include-fixed 2>/dev/null && find . -type f | sort) > /tmp/t243-$t.list 2>/dev/null
done
if diff -q /tmp/t243-$T1.list /tmp/t243-$T2.list >/dev/null 2>&1; then
  echo "  FILE LISTS IDENTICAL -- checking content hashes"
else
  echo "  FILE LISTS DIFFER:"; diff /tmp/t243-$T1.list /tmp/t243-$T2.list | head -20
fi
for t in $T1 $T2; do
  echo "  $t md5 of tree: `(cd $INC/$t/include-fixed 2>/dev/null && find . -type f | sort | xargs cat) | md5sum | cut -c1-12`"
done
