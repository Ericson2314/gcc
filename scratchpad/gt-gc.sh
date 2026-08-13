#!/bin/sh
# JOB 1 -- does the single `gt_ggc_mx_machine_function' actually MISCOLLECT?
#
# The routine in gtype-desc.cc walks i386's THREE fields:
#     (*x).stack_locals, (*x).split_stack_varargs_pointer, (*x).fs.cfa_reg
# aarch64's `machine_function' begins with `struct aarch64_frame frame', whose
# first member is `poly_int64 reg_offset[0]'.  So marking an aarch64
# `crtl->machine' passes reg_offset[0].coeffs[0] to gt_ggc_mx_stack_local_entry
# as if it were a pointer.
#
# The arm therefore runs each base BOTH WITH AND WITHOUT collection forced.
# A base that compiles clean without GC and dies with GC forced is the
# miscollection; a base that is fine both ways is a measured negative and is
# reported as one.  --param ggc-min-expand=0 --param ggc-min-heapsize=0 makes
# ggc_collect actually collect at every collection point.
#
# NOTE ON WHAT THIS CANNOT SEE: the OTHER half of the bug -- aarch64's
# saved_gprs/saved_fprs/saved_prs/tpidr2_block/za_save_buffer/... never being
# marked at all -- is a premature free, which is silent by construction.  A
# clean run here is NOT evidence that half is absent.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b-a2c4f72addc68d136-pair}
V=17.0.0
OUT=${OUT:-/tmp/gt-gc}
IN=${IN:-$SRC/scratchpad/big.c}

got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$B/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $B configured from '$got', not $SRC"; exit 9; }
[ -s "$IN" ] || { echo "FATAL: missing input $IN"; exit 9; }
[ -x "$B/gcc/cc1" ] || { echo "FATAL: no cc1 in $B/gcc"; exit 9; }
# Non-vacuity: the bug under test must actually be present in this build dir,
# or a clean run means nothing.  Assert the ONE definition, and that its body
# is i386's.
# State WHICH of the two worlds this build dir is in, rather than asserting a
# fixed number: the arm is run both before and after the fix and must be
# readable either way.  A single unsuffixed definition and nothing else is the
# broken state; per-base definitions plus a dispatcher is the fixed one.
plain=$(grep -c '^gt_ggc_mx_machine_function (void \*x_p)' \
	"$B/gcc/gtype-desc.cc" 2>/dev/null || echo 0)
perbase=$(cat "$B"/gcc/gt-*.h 2>/dev/null \
	  | grep -c '^gt_ggc_mx_machine_function_' || true)
echo "gt_ggc_mx_machine_function: $plain unsuffixed (shared), \
$perbase per-base definitions"
[ "$plain" = 1 ] || { echo "FATAL: expected exactly one unsuffixed definition \
(the shared entry point), found $plain"; exit 9; }
mkdir -p "$OUT"
echo "input: $IN  ($(wc -l < "$IN") lines, md5 $(md5sum < "$IN" | cut -c1-32))"

for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  c=$B/lib/gcc/$V/$t/specs-config
  [ -s "$c" ] || { echo "FATAL: no specs-config at $c"; exit 9; }
  for arm in nogc gc; do
    case $arm in
      nogc) P="" ;;
      gc)   P="--param ggc-min-expand=0 --param ggc-min-heapsize=0" ;;
    esac
    tag=$t-$arm
    (cd "$B/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" $P \
        "$IN" -o "$OUT/$tag.s") > "$OUT/$tag.out" 2> "$OUT/$tag.err"
    rc=$?
    sz=$( [ -f "$OUT/$tag.s" ] && wc -c < "$OUT/$tag.s" || echo 0 )
    md=$( [ -s "$OUT/$tag.s" ] && md5sum < "$OUT/$tag.s" | cut -c1-12 || echo -)
    echo "$tag: rc=$rc bytes=$sz md5=$md"
    [ "$rc" = 0 ] || sed -n 1,6p "$OUT/$tag.err"
  done
done
