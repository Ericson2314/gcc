#!/bin/sh
# a51a0e8b2b458063b-ubshift.sh -- does `cc1' shift by more than 63 inside
# aarch64's AARCH64_APPROX_MODE?  (task #185)
#
# WHY ONLY ONE OBJECT IS INSTRUMENTED.  A whole sanitized 47-base build costs
# hours and answers a wider question than the one asked.  The site under test
# is entirely inside `mt-aarch64/aarch64.o' (AARCH64_APPROX_MODE is an inline
# in aarch64-protos.h with three callers, all in aarch64.cc), so that one
# object is recompiled with -fsanitize=shift and `cc1' relinked against
# libubsan.  Everything else in the binary is the build's own object.
#
# THE NULL RESULT THIS SCRIPT EXISTS TO MAKE IMPOSSIBLE.  "UBSan reported
# nothing" and "UBSan was never enabled on that translation unit" produce the
# same empty log.  So ARM 1 refuses to score until it has seen
# `__ubsan_handle_shift_out_of_bounds' as an undefined reference in the
# rebuilt object -- i.e. the compiler really did instrument the shifts in this
# file -- and the run is only scored after that.  A clean ARM 2 without a
# passing ARM 1 is a NULL RESULT and this script exits 9 rather than 0.
#
# The reproducer needs an SVE vector-float mode, not Advanced SIMD: measured in
# the 47-base numbering, V4SFmode's old shift count is 35 (in range, wrong bit
# but defined) while VNx4SFmode's is 136 and VNx8DFmode's is 219.  A plain
# `float' loop at -Ofast without +sve would report NOTHING and would look
# exactly like a fixed compiler.
#
# usage: a51a0e8b2b458063b-ubshift.sh <builddir> <tag>
set -eu
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
case "$D" in */b-a51a0e8b2b458063b*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;; esac
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 in $D/gcc"; exit 9; }

O=/tmp/ub-a51a0e8b2b458063b-$TAG
rm -rf "$O"; mkdir -p "$O"

cat > "$O/sve.c" <<'EOF'
void div_loop (float *a, float *b, int n)
{ for (int i = 0; i < n; i++) a[i] = a[i] / b[i]; }
double sq (double x) { return __builtin_sqrt (x); }
float rsq (float *a, float *b, int n)
{ for (int i = 0; i < n; i++) a[i] = 1.0f / __builtin_sqrtf (b[i]); return a[0]; }
EOF

echo "== ARM 1: rebuild mt-aarch64/aarch64.o with -fsanitize=shift, relink cc1"
rm -f "$D/gcc/mt-aarch64/aarch64.o"
sh "$S/eb-shell.sh" "cd $D/gcc && make mt-aarch64/aarch64.o \
   CXXFLAGS='-O1 -g -fsanitize=shift' " > "$O/rebuild.out" 2> "$O/rebuild.err"
[ -f "$D/gcc/mt-aarch64/aarch64.o" ] || { echo "FATAL: object not rebuilt"; tail -20 "$O/rebuild.err"; exit 9; }

nsym=$(sh "$S/eb-shell.sh" "nm -u $D/gcc/mt-aarch64/aarch64.o" \
        | grep -c 'ubsan_handle_shift_out_of_bounds' || true)
echo "  __ubsan_handle_shift_out_of_bounds undefined refs: $nsym"
[ "$nsym" -ge 1 ] || { echo "FATAL (NULL RESULT): the object is NOT instrumented;
  a clean ARM 2 would mean nothing.  Not scoring."; exit 9; }

rm -f "$D/gcc/cc1"
sh "$S/eb-shell.sh" "cd $D/gcc && make cc1 LDFLAGS='-fsanitize=shift'" \
   > "$O/link.out" 2> "$O/link.err"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: cc1 did not relink"; tail -20 "$O/link.err"; exit 9; }

echo "== ARM 2: compile the SVE reproducer for aarch64"
V=$(cat "$(cat "$D/MY-SRC")/gcc/BASE-VER")
CFG="$D/lib/gcc/$V/aarch64-unknown-linux-gnu/specs-config"
[ -s "$CFG" ] || { echo "FATAL: no aarch64 specs-config at $CFG (run mt-specs.sh)"; exit 9; }
: > "$O/run.err"; : > "$O/run.out"
for opt in "-Ofast -march=armv8.2-a+sve" "-Ofast -march=armv8.2-a+sve2" "-O3 -ffast-math -march=armv8.2-a+sve"; do
  UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0 \
  ASAN_OPTIONS=detect_leaks=0:handle_segv=2:allow_user_segv_handler=0 \
  sh "$S/eb-shell.sh" "cd $O && $D/gcc/cc1 -quiet -nostdinc -ftarget-config=$CFG \
      $opt sve.c -o out.s" >> "$O/run.out" 2>> "$O/run.err" || true
done

n=$(grep -c 'shift exponent' "$O/run.err" || true)
echo "  'shift exponent' UBSan reports: $n"
grep -m3 'shift exponent' "$O/run.err" || true
echo "TAG=$TAG INSTRUMENTED=yes SHIFT_REPORTS=$n"
