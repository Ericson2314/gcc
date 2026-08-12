#!/bin/sh
# The acceptance for task #63, BOTH arms.
#
# Arm 1 (the failure): an aarch64 target-config must accept -mabi=lp64.
# Arm 2 (the one that matters): an i386 target-config must REJECT -mabi=lp64
#   and accept -mabi=sysv.  A union that accepts every argument for every
#   target is worse than the bug, and only arm 2 can tell the difference.
#
# Scored by whether the driver emits the "unrecognized argument" diagnostic,
# never by exit status: the driver exits non-zero for unrelated reasons in a
# build tree (no crt files), so rc is not the signal.
#
# Two CONTROLS, because a script that cannot fail proves nothing:
#   C1  the four cells must not all agree.  If -mabi= were rejected (or
#       accepted) everywhere, every cell would print the same and the table
#       would look like an answer.
#   C2  a nonsense argument -mabi=nonesuch must be rejected under BOTH
#       configs.  This is what catches "the option table was widened into
#       accepting anything", which is the failure mode arm 2 exists for and
#       which arm 2 alone cannot distinguish from a correct fix if the
#       aarch64 table happened to contain `sysv'.
set -u
B=${B:-/tmp/b-a79}
cd "$B/gcc" || exit 9
test -x ./xgcc || { echo "no xgcc in $B/gcc"; exit 9; }
A=./specs-aarch64-unknown-linux-gnu-config
I=./specs-x86_64-pc-linux-gnu-config
for f in "$A" "$I"; do
  test -f "$f" || { echo "missing target-config $f"; exit 9; }
done
: > /tmp/a79-mabi-empty.c

cell () {  # $1 config  $2 arg -> ACCEPT | REJECT
  out=`./xgcc -B. -ftarget-config="$1" "$2" -S -o /dev/null \
       /tmp/a79-mabi-empty.c 2>&1`
  case "$out" in
    *"unrecognized argument in option"*) echo REJECT ;;
    *) echo ACCEPT ;;
  esac
}

a_lp64=`cell "$A" -mabi=lp64`
a_sysv=`cell "$A" -mabi=sysv`
i_lp64=`cell "$I" -mabi=lp64`
i_sysv=`cell "$I" -mabi=sysv`
a_junk=`cell "$A" -mabi=nonesuch`
i_junk=`cell "$I" -mabi=nonesuch`

printf 'config           -mabi=lp64  -mabi=sysv  -mabi=nonesuch\n'
printf 'aarch64 config   %-11s %-11s %s\n' "$a_lp64" "$a_sysv" "$a_junk"
printf 'i386    config   %-11s %-11s %s\n' "$i_lp64" "$i_sysv" "$i_junk"
echo

rc=0
chk () { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (got $3, want $2)"; rc=1; fi; }
chk "arm1 aarch64 accepts lp64"  ACCEPT "$a_lp64"
chk "arm1 aarch64 rejects sysv"  REJECT "$a_sysv"
chk "arm2 i386    rejects lp64"  REJECT "$i_lp64"
chk "arm2 i386    accepts sysv"  ACCEPT "$i_sysv"
chk "C2   aarch64 rejects junk"  REJECT "$a_junk"
chk "C2   i386    rejects junk"  REJECT "$i_junk"
if [ "$a_lp64$a_sysv$i_lp64$i_sysv" = "ACCEPTACCEPTACCEPTACCEPT" ] \
   || [ "$a_lp64$a_sysv$i_lp64$i_sysv" = "REJECTREJECTREJECTREJECT" ]; then
  echo "FAIL C1  all four cells agree; the table is not per-target at all"
  rc=1
else
  echo "PASS C1  the four cells do not all agree"
fi
echo "OVERALL rc=$rc"
exit $rc
