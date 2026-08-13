#!/bin/sh
# #119 -- the acceptance arms for the specs-config connecting rule.
#
# Every arm is BOTH-SIDED (two targets) or NEGATIVE (something must fail).
# Nothing here checks a file's name or its existence alone: #113b banked a
# green on two trees with correct names and correct --host each, and the
# content was one machine's answer served to both.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b119}
I=${I:-/tmp/b119-inst}
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
V=17.0.0
fail=0
note () { echo "  $*"; }
bad () { echo "  FAIL: $*"; fail=1; }

# The installed compiler must be reached with NOTHING pointing it anywhere:
# no -B, no GCC_EXEC_PREFIX, no cwd inside the build tree.
unset GCC_EXEC_PREFIX

echo "=============================================================="
echo "ARM 1 (BOTH-SIDED): installed <triple>-gcc finds its own config, no -B"
echo "=============================================================="
tmp=$(mktemp -d) || exit 9
echo 'int mt_probe;' > "$tmp/c.c"
for t in $T1 $T2; do
  drv="$I/bin/$t-gcc"
  want="$I/lib/gcc/$V/$t/specs-config"
  if [ ! -x "$drv" ]; then bad "no installed driver $drv"; continue; fi
  ( cd "$tmp" && "$drv" -### -c c.c ) > "$tmp/$t.out" 2>&1
  if [ ! -s "$tmp/$t.out" ]; then bad "$t: driver printed nothing -- refusing to score"; continue; fi
  if grep -F -e "-ftarget-config=$want" "$tmp/$t.out" > /dev/null; then
    note "OK: $t -> $want"
  else
    bad "$t did not pass -ftarget-config=$want"
    sed 's/^/        /' "$tmp/$t.out" | head -5
  fi
done
# CROSS-CONTAMINATION: neither driver may name the other's file.
for t in $T1 $T2; do
  other=$T2; [ "$t" = "$T2" ] && other=$T1
  if [ -s "$tmp/$t.out" ] && grep -F -e "/$other/" "$tmp/$t.out" > /dev/null; then
    bad "$t's driver names $other's directory"
  fi
done

echo
echo "=============================================================="
echo "ARM 2 (NEGATIVE): remove one target's config, that target only must fail"
echo "=============================================================="
# The point is asymmetry: if BOTH stopped working the arm would prove nothing
# about which file was being read.
cfg="$I/lib/gcc/$V/$T1/specs-config"
mv "$cfg" "$cfg.away" || exit 9
( cd "$tmp" && "$I/bin/$T1-gcc" -### -c c.c ) > "$tmp/neg1.out" 2>&1; rc1=$?
( cd "$tmp" && "$I/bin/$T2-gcc" -### -c c.c ) > "$tmp/neg2.out" 2>&1; rc2=$?
mv "$cfg.away" "$cfg" || { echo "  FATAL: could not restore $cfg"; exit 9; }
if [ $rc1 -eq 0 ]; then
  bad "$T1 still succeeded with its config removed -- something else answers"
elif grep -F -e "$cfg" "$tmp/neg1.out" > /dev/null; then
  note "OK: $T1 rc=$rc1 and names the missing file"
else
  bad "$T1 failed but did not name $cfg"
fi
if [ $rc2 -eq 0 ]; then
  note "OK: $T2 unaffected (rc=0) -- the failure was specific to $T1's file"
else
  bad "$T2 ALSO failed (rc=$rc2): the negative arm is not target-specific,"
  bad "  so arm 1 cannot be attributed to per-target files"
fi

echo
echo "=============================================================="
echo "ARM 3 (BOTH-SIDED, CONTENT): the two configs differ in PROBED lines"
echo "=============================================================="
a="$I/lib/gcc/$V/$T1/specs-config"
b="$I/lib/gcc/$V/$T2/specs-config"
diff "$a" "$b" > "$tmp/d" 2>&1
d=$(grep -c '^[<>]' "$tmp/d")
# Lines that are merely the target's own name or a path.  #113b's false green
# had SIX such lines and NOTHING else; that is the shape to refuse.
namey=$(grep '^[<>]' "$tmp/d" | grep -c -E "$T1|$T2|/nix/store")
probed=$((d - namey))
note "differing lines: $d, of which $namey are the target's own name or a path"
note "PROBED capability lines that differ: $probed"
if [ "$probed" -lt 4 ]; then
  bad "fewer than 4 probed lines differ.  That is #113b's measured false green:"
  bad "  two files that name different targets and describe the same machine."
else
  note "OK: e.g."
  grep '^[<>]' "$tmp/d" | grep -E '^[<>] as_' | head -4 | sed 's/^/        /'
fi
# and both must be non-trivial
for f in "$a" "$b"; do
  n=$(grep -c -v -e '^#' -e '^$' "$f")
  [ "$n" -ge 50 ] || bad "$f has only $n data lines"
done

echo
echo "=============================================================="
echo "ARM 4 (NEGATIVE): the installed spec file carries no build-tree path"
echo "=============================================================="
for t in $T1 $T2; do
  f="$I/lib/gcc/$V/$t/specs"
  if [ ! -f "$f" ]; then bad "no installed spec file $f"; continue; fi
  n=$(grep -F -c -e "$B/" "$f") || n=0
  m=$(grep -F -c -e "$I/lib/gcc/$V/$t/" "$f") || m=0
  if [ "$n" -ne 0 ]; then
    bad "$t: $n reference(s) to the build tree survive in the installed specs"
  elif [ "$m" -eq 0 ]; then
    bad "$t: installed specs names the installed directory zero times -- the"
    bad "  rewrite check would pass vacuously"
  else
    note "OK: $t: 0 build-tree paths, $m installed path(s)"
  fi
done

echo
echo "=============================================================="
echo "ARM 5 (NON-VACUITY): cc1 really carries BOTH back ends"
echo "=============================================================="
c="$B/gcc/cc1"
for sym in targetm_i386 targetm_aarch64; do
  if sh "$S/eb-shell.sh" "nm -C $c | grep -c -w $sym" > "$tmp/n" 2>&1 && \
     [ "$(cat "$tmp/n")" != 0 ]; then
    note "OK: cc1 defines $sym ($(cat "$tmp/n") match(es))"
  else
    bad "cc1 has no $sym -- this is not a two-backend compiler"
  fi
done

echo
if [ $fail = 0 ]; then echo "ALL ARMS PASSED"; else echo "SOME ARMS FAILED"; fi
rm -rf "$tmp"
exit $fail
