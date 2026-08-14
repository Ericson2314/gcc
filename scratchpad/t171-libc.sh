#!/bin/sh
# #171 PART B -- IS `config/linux.cc' IDENTICAL ACROSS BASES BECAUSE OF THE
# FILE, OR BECAUSE OF THE TARGET LIST?
#
# `t171-partb.sh' finds mt-i386/linux.o, mt-s390/linux.o, mt-mips/linux.o and
# mt-rs6000/linux.o byte-identical once the three `linux_*' renames are
# normalised away, and their only undefined references are `global_options'
# and `targ_caps' -- no per-base callee at all.  Read naively that says the
# file is target-neutral and its three renames are pure duplication.
#
# It does not say that, and this is the `two back ends cannot tell' shape with
# eight back ends instead of two.  `config/linux.h:31':
#
#     #ifdef SINGLE_LIBC
#     #define OPTION_GLIBC_P(opts)  (DEFAULT_LIBC == LIBC_GLIBC)     <- constant
#     #else
#     #define OPTION_GLIBC_P(opts)  ((opts)->x_linux_libc == LIBC_GLIBC)  <- runtime
#     #endif
#
# and `config.gcc:1115' gives `*-*-uclinux*' `DEFAULT_LIBC=LIBC_UCLIBC
# SINGLE_LIBC' through tm_defines.  All eight configured targets here are
# glibc, so all eight take the second branch and all eight agree.  Add one
# uclinux target and they do not.
#
# So the arm below compiles the SAME source with the same command plus that
# target's own tm_defines, and requires the code to CHANGE.  What it
# demonstrates is that the compile-time branch is live and that the identical
# result above is a function of the target list.
#
# WHAT IT DOES NOT DEMONSTRATE, said out loud: it is a -D on the command line,
# not a configured uclinux triple, so it shows the MECHANISM rather than
# reproducing the configuration.  (Reproducing it needs its own finding first:
# `arm-linux-gnueabihf' and `arm-uclinuxfdpiceabi' are two triples of ONE back
# end, and this build keys tm-<base>.h by cpu_type, so the two tm_defines sets
# collapse into one header.  That is a separate instance of the same bug and
# is not in scope here.)
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
B=${2:-i386}
case "$D" in
  */b-a0e5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
O=$D/partb-libc; rm -rf "$O"; mkdir -p "$O"

sh "$S/eb-shell.sh" "cd $D/gcc && make -n mt-$B/linux.o" > "$O/mk" 2> "$O/mkerr"
cmd=$(grep -m1 -F -- "-o mt-$B/linux.o" "$O/mk" | sed 's/^[ \t]*//')
[ -n "$cmd" ] || { echo "FATAL: no compile command for mt-$B/linux.o"; cat "$O/mkerr"; exit 9; }

for arm in glibc uclinux; do
  extra=""
  [ "$arm" = uclinux ] && extra="-DSINGLE_LIBC -UDEFAULT_LIBC -DDEFAULT_LIBC=LIBC_UCLIBC"
  out=$(printf '%s\n' "$cmd" | sed "s#-o [^ ]*#$extra -o $O/$arm.o#")
  sh "$S/eb-shell.sh" "cd $D/gcc && $out" > "$O/$arm.out" 2> "$O/$arm.err"
  echo "$arm: rc=$?  $(wc -c < "$O/$arm.o" 2>/dev/null || echo 0) bytes"
  [ -s "$O/$arm.o" ] || { echo "FATAL: $O/$arm.o empty"; tail -10 "$O/$arm.err"; exit 9; }
  sh "$S/eb-shell.sh" "objdump -drC --no-show-raw-insn '$O/$arm.o'" \
    | sed -e '1,2d' -e "s/_$B\\b/_MT/g" > "$O/$arm.dis"
done

echo
if cmp -s "$O/glibc.dis" "$O/uclinux.dis"; then
  echo "IDENTICAL -- the SINGLE_LIBC branch is DEAD, and the three linux_*"
  echo "renames really are pure duplication.  (This would be a finding, not a"
  echo "green: it would mean config/linux.h:31 cannot change the object.)"
else
  echo "DIFFER -- the compile-time branch is live, so config/linux.cc IS a"
  echo "per-target compilation and 'identical across the eight configured"
  echo "targets' is a property of the LIST, not of the file:"
  diff "$O/glibc.dis" "$O/uclinux.dis" | sed 's/^/  /' | head -40
fi
