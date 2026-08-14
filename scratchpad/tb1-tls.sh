#!/bin/sh
# #163 -- CAN `HAVE_AS_TLS' BE VARIED PER TARGET?  Asked of the running cc1.
#
# THE NON-VACUITY ARM RUNS FIRST AND IS THE POINT OF THE SCRIPT.  Every other
# arm here reads a cc1 that was told `as_tls 0'; if that key is simply ignored
# -- which is exactly what the PRE-CHANGE compiler does, because unknown names
# in a target-config file are dropped without a word -- then "TLS still works"
# and "the capability is not wired" produce IDENTICAL output.  So arm 0
# establishes that the two configs differ in the one line, and the scoring arm
# requires the two ASSEMBLY FILES to differ.  A run where they match is a
# FAILURE, and on the pre-change compiler that is what it reports.
#
# Both sides, in one cc1, from one source:
#   as_tls 1  -> the back end's real TLS sequence
#   as_tls 0  -> emutls (__emutls_get_address), which is what a target whose
#                assembler cannot spell TLS relocations has to use
#
# usage: tb1-tls.sh <builddir> [tag]
set -u
D=${1:?build dir}
TAG=${2:-tls}
case "$D" in
  */b-agent-aab545de8b02de843*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D/make-top.rc absent -- unstamped log, refusing to score"; exit 9; }
rc=$(cat "$D/make-top.rc")

T=${MT_TLS_TARGET:-x86_64-pc-linux-gnu}
OUT="$D/$TAG"; rm -rf "$OUT"; mkdir -p "$OUT"

cat > "$OUT/tls.c" <<'EOF'
__thread int tv;
int *tls_addr (void) { return &tv; }
EOF

for v in 1 0; do
  printf 'target %s\nas_tls %s\n' "$T" "$v" > "$OUT/cfg-$v"
done

# ---- arm 0: NON-VACUITY -------------------------------------------------
# The two config files must differ, and differ ONLY in the as_tls line, or the
# comparison below is between two identical inputs and cannot fail.
if cmp -s "$OUT/cfg-1" "$OUT/cfg-0"; then
  echo "FATAL: the two target-config files are identical"; exit 9
fi
nd=$(diff "$OUT/cfg-1" "$OUT/cfg-0" | grep -c '^[<>]')
[ "$nd" = 2 ] || { echo "FATAL: configs differ in $nd lines, expected 2 (the as_tls pair)"; exit 9; }
echo "arm 0  non-vacuity: configs differ in exactly the as_tls line"

for v in 1 0; do
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 \
      -ftarget-config="$OUT/cfg-$v" "$OUT/tls.c" -o "$OUT/tls-$v.s" ) \
    > "$OUT/tls-$v.out" 2> "$OUT/tls-$v.err"
  r=$?
  if [ "$r" != 0 ] || [ ! -s "$OUT/tls-$v.s" ]; then
    echo "FATAL: cc1 rc=$r with as_tls=$v"; sed -n 1,10p "$OUT/tls-$v.err"; exit 9
  fi
done

echo
echo "target $T   (build rc=$rc)"
for v in 1 0; do
  emu=$(grep -c '__emutls' "$OUT/tls-$v.s" || true)
  printf '  as_tls %s : %5s bytes  md5 %s  __emutls hits %s\n' \
    "$v" "$(wc -c < "$OUT/tls-$v.s")" \
    "$(md5sum < "$OUT/tls-$v.s" | cut -c1-12)" "$emu"
done

echo
if cmp -s "$OUT/tls-1.s" "$OUT/tls-0.s"; then
  echo "RESULT: IDENTICAL -- as_tls changes nothing; the capability is NOT wired."
  echo "        (This is the correct reading for a compiler built before #163:"
  echo "         as_tls is an unknown key and read_target_caps drops it.)"
  exit 1
fi
e1=$(grep -c '__emutls' "$OUT/tls-1.s" || true)
e0=$(grep -c '__emutls' "$OUT/tls-0.s" || true)
if [ "$e1" != 0 ]; then
  echo "RESULT: WRONG DIRECTION -- as_tls=1 emitted emutls."; exit 1
fi
if [ "$e0" = 0 ]; then
  echo "RESULT: WRONG DIRECTION -- as_tls=0 did NOT fall back to emutls."; exit 1
fi
echo "RESULT: as_tls=1 emits the real TLS sequence, as_tls=0 emits emutls."
echo "        One cc1, one source, one line of target config."
