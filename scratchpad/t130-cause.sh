#!/bin/sh
# #130 -- THE DIAGNOSIS, BOTH-SIDED, IN THE RUNNING cc1.
#
# What must be shown, and neither half alone is evidence:
#   (a) with aarch64 selected, targetm_attr is AARCH64's table, and its
#       have_attr_preferred_for_size is FALSE -- the absent case -- while its
#       preferred_for_size slot still answers, because genattr already put
#       hook_int_rtx_1 (constant 1) behind that name for a base without the
#       attribute;
#   (b) with x86_64 selected, targetm_attr is I386's table and the same
#       boolean is TRUE.
# (b) is what distinguishes "fixed" from "everyone now gets the same new
# answer" (PRINCIPLES 4, both-sided evidence).
#
# ONE BREAKPOINT PER RUN, and gdb's own `info breakpoints' is printed and
# checked against the function under test: an arm that set three breakpoints
# in one run once read one function's return value under three names and
# scored a pass on it.
#
# `--args', NOT `gdb run <args>': the latter silently drops -ftarget-config,
# which selects the target -- so the whole measurement would be of a compiler
# that selected nothing.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b130}
CC1=$B/gcc/cc1
TC=$B/gcc/../lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
TCX=$B/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
[ -x "$CC1" ] || { echo "FATAL no cc1"; exit 9; }
[ -f "$TC" ] || { echo "FATAL no aarch64 specs-config"; exit 9; }
[ -f "$TCX" ] || { echo "FATAL no x86_64 specs-config"; exit 9; }
printf 'int g (int a) { return a + 1; }\n' > "$B/fn-add.c"

mkcmd () {
cat <<EOF
set confirm off
set pagination off
break mt_get_attr_enabled
info breakpoints
run
echo \\nMT130 --- gdb stopped here:\\n
frame
echo \\nMT130 which base is in force:\\n
p targetm_attr->name
echo \\nMT130 the four HAVE_ATTR booleans of THAT base:\\n
p targetm_attr->have_attr_length
p targetm_attr->have_attr_enabled
p targetm_attr->have_attr_preferred_for_size
p targetm_attr->have_attr_preferred_for_speed
echo \\nMT130 what sits in the preferred_for_size slot:\\n
p targetm_attr->preferred_for_size
echo \\nMT130 and in the enabled slot:\\n
p targetm_attr->enabled
echo \\nMT130 what this call returns:\\n
finish
quit
EOF
}

for arm in aarch64 x86_64; do
  case $arm in
    aarch64) cfg=$TC;  extra="-mlittle-endian -mabi=lp64" ;;
    x86_64)  cfg=$TCX; extra="" ;;
  esac
  mkcmd > "$B/gdb-$arm.cmd"
  echo "=========== ARM: $arm"
  sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdb-$arm.cmd --args $CC1 -quiet \
    -nostdinc $B/fn-add.c $extra -ftarget-config=$cfg -o $B/gdb-$arm.s" \
    > "$B/gdb-$arm.out" 2> "$B/gdb-$arm.err"
  echo "gdb rc=$?"
  # gdb's OWN report of what it broke on, matched against the function under
  # test.  If this line does not name mt_get_attr_enabled, every
  # reading below belongs to some other function.
  if grep -qE '^Breakpoint [0-9]+, mt_get_attr_enabled' "$B/gdb-$arm.out"; then
    echo "  breakpoint confirmed by gdb: mt_get_attr_enabled"
  else
    echo "  FATAL: gdb did not report a breakpoint on the function under test"
  fi
  sed -n '/MT130/,$p' "$B/gdb-$arm.out"
  echo "-- stderr tail:"; tail -2 "$B/gdb-$arm.err"
done
