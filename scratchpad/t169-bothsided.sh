#!/bin/sh
# #169 / #162 -- BOTH-SIDED evidence for the AUTO_INC_DEC conversion.
#
# PRINCIPLES section 4: "Showing target A gets A's answer proves nothing unless
# you also show target B still gets B's."  Here A is aarch64, which now gets
# AUTO_INC_DEC = 1, and B is x86_64, which must still get 0 -- x86 genuinely
# has no auto-increment addressing, so a change in ITS output would mean the
# conversion had started answering for everyone with the other value, which is
# the same bug pointed the other way.
#
# usage: t169-bothsided.sh <builddir> <snapshot-srcdir>
set -u
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
V=17.0.0
OUT=$D/t169-bothsided
mkdir -p "$OUT"
rc=0

grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:-50}" ] \
  || { echo "FATAL: snapshot anchor is not ${WANT_ANCHOR:-50}"; exit 9; }
IN=$SRC/scratchpad/t169-autoinc.c
[ -s "$IN" ] || { echo "FATAL: input $IN missing or empty"; exit 9; }

run () { # $1 target  $2 tag  $3 input  ... flags
  t=$1; tag=$2; in=$3; shift 3
  c=$D/lib/gcc/$V/$t/specs-config
  [ -s "$c" ] || { echo "FATAL: no specs-config for $t at $c"; exit 9; }
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc "$@" -ftarget-config="$c" \
      "$in" -o "$OUT/$tag.s" ) > "$OUT/$tag.out" 2> "$OUT/$tag.err"
  r=$?
  [ $r = 0 ] && [ -s "$OUT/$tag.s" ] \
    || { echo "$tag: FAIL rc=$r"; sed -n 1,8p "$OUT/$tag.err"; rc=1; return 1; }
  echo "$tag [$t] in=$in  $(wc -c < "$OUT/$tag.s") bytes  md5 $(md5sum < "$OUT/$tag.s" | cut -c1-12)"
}

echo "=== ARM 1 (non-vacuity, FIRST).  Both compilers must run and emit."
run x86_64-pc-linux-gnu       x86-ai   "$IN" -O2 || true
run aarch64-unknown-linux-gnu a64-ai   "$IN" -O2 || true
[ -s "$OUT/x86-ai.s" ] && [ -s "$OUT/a64-ai.s" ] \
  || { echo "FATAL: an empty .s scores every grep below as 0, which reads as"
       echo "       'no auto-inc addressing' -- the exact conclusion under test"; exit 9; }

echo
echo "=== ARM 2 (the recorded x86_64 bar, unchanged).  PRINCIPLES section 6:"
echo "=== two bases, -O2, big.c -> 12369 bytes / md5 378fc33c1e70."
run x86_64-pc-linux-gnu x86-big "$SRC/scratchpad/big.c" -O2 || true
got=$(md5sum < "$OUT/x86-big.s" | cut -c1-12)
if [ "$got" = 378fc33c1e70 ]; then echo "  x86_64 bar: MATCHES 378fc33c1e70"
else echo "  x86_64 bar: MOVED -- was 378fc33c1e70, now $got"; rc=1; fi

echo
echo "=== ARM 3 (the per-base DATA).  The two supply-side objects must not"
echo "=== agree about auto_inc_dec.  A green codegen arm says nothing about"
echo "=== whether the two tables differ (PRINCIPLES: separate arms on the"
echo "=== data and on the selection)."
for b in i386 aarch64; do
  o=$D/gcc/target-cumargs-$b.o
  [ -f "$o" ] || { echo "FATAL: $o missing"; exit 9; }
  # `mt_base_insn' is `const char *name; bool have_lo_sum, have_rotate,
  # have_rotatert, auto_inc_dec; int (*load_extend_op)(int);' -- so the four
  # bools are the four bytes at offset 8.  Read THOSE rather than md5-ing the
  # object: two objects differing SOMEWHERE is not evidence they differ HERE
  # (PRINCIPLES: a check that cannot say which thing disagrees is most of a
  # check).  The fourth byte is auto_inc_dec.
  a=$(nm "$o" | awk '$3 ~ /mt_base_insn$/ { print $1 }')
  [ -n "$a" ] || { echo "FATAL: no mt_base_insn in $o"; exit 9; }
  off=$(printf '%d' "0x$a")
  bytes=$(objdump -sj .rodata "$o" \
          | awk -v want=$((off + 8)) '
              /^ [0-9a-f]+ / { addr = strtonum("0x" $1)
                if (want >= addr && want < addr + 16) {
                  # rebuild the 16 hex bytes of this row, then take 4 from it
                  s = $2 $3 $4 $5
                  k = (want - addr) * 2
                  print substr(s, k + 1, 8) } }')
  echo "  target-cumargs-$b.o  mt_base_insn+8 = $bytes"
  echo "    (have_lo_sum have_rotate have_rotatert AUTO_INC_DEC)"
  eval "AID_$b=\$(printf '%s' \"\$bytes\" | cut -c7-8)"
done
i=$(eval echo \$AID_i386); a=$(eval echo \$AID_aarch64)
echo "  auto_inc_dec byte: i386=$i aarch64=$a"
[ -n "$i" ] && [ -n "$a" ] || { echo "FATAL: could not read the byte; an empty"
  echo "       read compares equal to another empty read and scores PASS"; exit 9; }
if [ "$i" != "$a" ]; then echo "  PASS: the two bases disagree, in the data"
else echo "  FAIL: both bases carry the same auto_inc_dec"; rc=1; fi
echo "  ...and the whole-object md5s, for the record:"
for b in i386 aarch64; do
  echo "    target-cumargs-$b.o  md5 $(md5sum < "$D/gcc/target-cumargs-$b.o" | cut -c1-12)"
done

echo
echo "=== ARM 4 (the SELECTION, both-sided).  One cc1, one source, one set of"
echo "=== flags; only -ftarget-config differs.  auto-inc-dec.cc:1696 gates the"
echo "=== whole pass on \`if (!AUTO_INC_DEC) return false', so the pass's RTL"
echo "=== dump exists exactly when the flag reads true.  A dump file is a much"
echo "=== better observable than an addressing mode in the output: it is the"
echo "=== flag's own consumer, not a downstream effect that other heuristics"
echo "=== can suppress (measured: at -O2 on this input aarch64 forms no"
echo "=== auto-inc address even with the pass enabled, so the codegen grep"
echo "=== would have scored this conversion as absent)."
for pair in "x86_64-pc-linux-gnu:x86:0" "aarch64-unknown-linux-gnu:a64:1"; do
  t=${pair%%:*}; rest=${pair#*:}; tag=${rest%%:*}; want=${rest#*:}
  dd=$OUT/dump-$tag; rm -rf "$dd"; mkdir -p "$dd"
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -fdump-rtl-auto_inc_dec \
      -dumpbase "$dd/t" -ftarget-config="$D/lib/gcc/$V/$t/specs-config" \
      "$IN" -o "$dd/x.s" ) > "$dd/out" 2> "$dd/err"
  [ -s "$dd/x.s" ] || { echo "FATAL: $t emitted nothing; a missing dump would"
                        echo "       then mean 'the compile failed', not 'the"
                        echo "       pass was gated off'"; exit 9; }
  got=0; [ -n "$(find "$dd" -name '*auto_inc_dec*' -print -quit)" ] && got=1
  echo "  $t: auto_inc_dec pass ran = $got (want $want)"
  [ "$got" = "$want" ] || { echo "    FAIL"; rc=1; }
done
[ $rc = 0 ] && echo "  PASS: the pass runs for aarch64 and not for x86_64, from ONE binary"

echo
echo "rc=$rc"
exit $rc
