#!/bin/sh
# a51a0e8b2b458063b-bothsided.sh -- aarch64 codegen either side of the
# AARCH64_APPROX_MODE change, on the inputs that actually reach the site.
#
# EXPECTED RESULT IS "NO CHANGE", AND THAT IS THE POINT.  Every in-tree
# `cpu_approx_modes' value is 0 or ~0, so the bit the old code computed was
# irrelevant to the answer even when the shift was undefined.  A codegen
# DIFFERENCE here would be a finding, not a success.
#
# The inputs are chosen to REACH `use_rsqrt_p' / `aarch64_emit_approx_div' /
# `aarch64_emit_approx_sqrt': they need !flag_trapping_math &&
# flag_unsafe_math_optimizations, i.e. -Ofast, and an SVE mode to exercise the
# formerly-undefined shift counts (136 .. 219) rather than only the in-range
# Advanced SIMD ones (20 .. 37).
#
# usage: a51a0e8b2b458063b-bothsided.sh <builddir> <tag>
set -eu
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
case "$D" in */b-a51a0e8b2b458063b*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;; esac
CC1=${MT_CC1:-$D/gcc/cc1}
[ -x "$CC1" ] || { echo "FATAL: no cc1 at $CC1"; exit 9; }
V=$(cat "$(cat "$D/MY-SRC")/gcc/BASE-VER")
O=/tmp/bs-a51a0e8b2b458063b-$TAG
rm -rf "$O"; mkdir -p "$O"

cat > "$O/fp.c" <<'EOF'
void div_loop (float *a, float *b, int n)
{ for (int i = 0; i < n; i++) a[i] = a[i] / b[i]; }
void ddiv_loop (double *a, double *b, int n)
{ for (int i = 0; i < n; i++) a[i] = a[i] / b[i]; }
void rsqrt_loop (float *a, float *b, int n)
{ for (int i = 0; i < n; i++) a[i] = 1.0f / __builtin_sqrtf (b[i]); }
void sqrt_loop (double *a, double *b, int n)
{ for (int i = 0; i < n; i++) a[i] = __builtin_sqrt (b[i]); }
float sdiv (float a, float b) { return a / b; }
double dsqrt (double x) { return __builtin_sqrt (x); }
EOF

for t in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  cfg="$D/lib/gcc/$V/$t/specs-config"
  [ -s "$cfg" ] || { echo "FATAL: no specs-config for $t"; exit 9; }
  case $t in
    aarch64*) archs="-march=armv8.2-a+sve -march=armv8.2-a+sve2 -march=armv8-a" ;;
    *)        archs="-march=x86-64" ;;
  esac
  for a in $archs; do
    n=$(printf '%s' "$a" | tr -c 'A-Za-z0-9' '_')
    ( cd "$O" && "$CC1" -quiet -nostdinc -Ofast -ftarget-config="$cfg" \
        $a fp.c -o "$t$n.s" ) > "$O/$t$n.out" 2> "$O/$t$n.err" || true
    if [ -s "$O/$t$n.s" ]; then
      echo "$t $a : $(wc -c < "$O/$t$n.s") bytes  md5 $(md5sum < "$O/$t$n.s" | cut -c1-12)"
    else
      echo "$t $a : NO OUTPUT  (rc nonzero or empty) -- $(head -1 "$O/$t$n.err")"
    fi
  done
done
# Non-vacuity: the site is only reached when these expansions actually happen.
echo "reached-approx-path witnesses (aarch64 +sve):"
grep -c 'frecpe\|frsqrte\|fdiv\|fsqrt' "$O"/aarch64*sve.s 2>/dev/null || true
