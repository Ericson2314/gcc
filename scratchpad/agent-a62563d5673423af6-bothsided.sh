#!/bin/sh
# #208 -- x86_64 MUST be byte-identical across the fix.  x86_64 has been this
# branch's control all along, so a CFI change that moves it is a regression in
# the one target that was known good.
#
# WHY THIS EXISTS BESIDE `gcheck.sh'.  gcheck removes the *input* path as a
# variable but still passes `-ftarget-config=$D/lib/...', i.e. the BUILD DIR,
# which lands in `DW_AT_producer' and reshuffles the `.LASF' string table.  So
# at `-g' it reports DIFFERENT for two identical compilers in differently
# named build dirs -- which is what it did here, and the entire diff was that
# one string.  This drives BOTH compilers with ONE specs-config path and ONE
# input path, so the only remaining variable is the compiler itself.
#
# Legitimate because the two specs-configs are byte-identical (both
# md5 cfbc7a65e54e); asserted below rather than assumed, since if they ever
# diverge this comparison would be measuring the specs and not the compiler.
set -u
A=${A:?pre-fix build dir}
B=${B:?post-fix build dir}
IN=${IN:?absolute path to the input .c}
W=${W:-/tmp/w-a62563d5673423af6-bothsided}
T=${T:-x86_64-pc-linux-gnu}
V=17.0.0
mkdir -p "$W"
case $IN in /*) ;; *) echo "FATAL: IN must be ABSOLUTE (a relative path has produced a false green here)"; exit 9 ;; esac
[ -f "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

CA=$A/lib/gcc/$V/$T/specs-config
CB=$B/lib/gcc/$V/$T/specs-config
for c in "$CA" "$CB"; do [ -s "$c" ] || { echo "FATAL: no $c"; exit 9; }; done
ma=$(md5sum < "$CA" | cut -c1-12); mb=$(md5sum < "$CB" | cut -c1-12)
[ "$ma" = "$mb" ] || { echo "FATAL: specs-config differ ($ma vs $mb); this would compare specs, not compilers"; exit 9; }
echo "specs-config identical on both sides: md5 $ma  (using A's copy for BOTH)"

[ -x "$A/gcc/cc1" ] && [ -x "$B/gcc/cc1" ] || { echo "FATAL: missing cc1"; exit 9; }
# The two compilers must actually be different binaries, or "identical output"
# is vacuous -- it would just be one compiler measured twice.
ba=$(md5sum < "$A/gcc/cc1" | cut -c1-12); bb=$(md5sum < "$B/gcc/cc1" | cut -c1-12)
[ "$ba" != "$bb" ] || { echo "FATAL: both cc1 are the same binary ($ba); nothing is being compared"; exit 9; }
echo "cc1 A=$ba  B=$bb  (different binaries, so the comparison is not vacuous)"

rc=0
for opt in "-O2" "-O2 -g" "-O2 -fexceptions"; do
  tag=$(echo "$opt" | tr ' -' '__')
  for s in a b; do
    case $s in a) D=$A ;; b) D=$B ;; esac
    # RUN FROM ONE FIXED CWD, not from each build dir.  cc1's working
    # directory is recorded as DW_AT_comp_dir, so invoking `./cc1' from
    # `$D/gcc' makes the two `-g' outputs differ by the build-dir string --
    # the last remaining non-compiler variable, and the only diff left after
    # the specs-config path was pinned.  Same byte count, one string, and a
    # reshuffled .LASF table: exactly the shape that reads as a codegen change.
    ( cd "$W" && "$D/gcc/cc1" -quiet -nostdinc $opt -ftarget-config="$CA" \
        "$IN" -o "$W/$s$tag.s" ) > "$W/$s$tag.out" 2> "$W/$s$tag.err"
    [ -s "$W/$s$tag.s" ] || { echo "FATAL($s $opt): no output"; sed -n 1,5p "$W/$s$tag.err"; exit 9; }
  done
  xa=$(md5sum < "$W/a$tag.s" | cut -c1-12); xb=$(md5sum < "$W/b$tag.s" | cut -c1-12)
  za=$(wc -c < "$W/a$tag.s"); zb=$(wc -c < "$W/b$tag.s")
  if [ "$xa" = "$xb" ]; then
    printf '%-18s IDENTICAL  %s bytes  md5 %s\n' "$opt" "$za" "$xa"
  else
    printf '%-18s DIFFER     A %s/%s   B %s/%s\n' "$opt" "$za" "$xa" "$zb" "$xb"
    diff "$W/a$tag.s" "$W/b$tag.s" | head -30
    rc=1
  fi
done
exit $rc
