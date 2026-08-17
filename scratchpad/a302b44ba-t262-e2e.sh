#!/bin/sh
# End-to-end: does wiring --with-shared-libgcc MOVE A MEASURED NUMBER?
# Re-runs the real top-level `configure-target-specs-<t>' rule in mt-hdr, for
# both configured targets, and diffs `*libgcc_variants' before and after.
set -u
B=/home/jcericson/src/gnu/gcc/build/mt-hdr
S=/home/jcericson/src/gnu/gcc/multi-target
V=`cat $S/gcc/BASE-VER`
T1=aarch64-unknown-linux-musl
T2=armv6l-unknown-linux-gnueabihf
W=$S/scratchpad/t262e2e; rm -rf "$W"; mkdir -p "$W"

show () { # show <tag>
  for t in $T1 $T2; do
    f=$B/lib/gcc/$V/$t/specs
    echo "$1 $t libgcc_variants: `sed -n '/^\*libgcc_variants:/{n;p;}' $f`"
    echo "$1 $t specs-config: wc -l `wc -l < $B/lib/gcc/$V/$t/specs-config` grep -c . `grep -c . $B/lib/gcc/$V/$t/specs-config`"
  done
}

echo "=== BEFORE"; show BEFORE | tee "$W/before"

echo "=== refreshing mt-hdr/Makefile from the patched top-level Makefile.in"
( cd $B && ./config.status Makefile ) > "$W/cs.log" 2>&1 || { echo "config.status FAILED"; tail -5 "$W/cs.log"; exit 1; }
grep -q 'with-shared-libgcc' $B/Makefile || { echo "FAIL: refreshed Makefile still has no --with-shared-libgcc; measuring it would be vacuous"; exit 1; }
echo "  ok: --with-shared-libgcc now present in $B/Makefile"

for t in $T1 $T2; do
  sh $S/scratchpad/eb-shell.sh "cd $B && make configure-target-specs-$t TOOLS_DIR_FOR_$t=$B/tools/bin" \
    > "$W/$t.log" 2>&1
  echo "  configure-target-specs-$t rc=$?"
done

echo "=== AFTER"; show AFTER | tee "$W/after"
echo "=== DELTA"
diff "$W/before" "$W/after" && echo "(nothing moved)"
