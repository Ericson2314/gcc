#!/bin/sh
# WHICH xregno AND ymode REACH subreg_get_info WHEN rs6000 DIVIDES BY ZERO.
#
# The build has no debug info, so this reads the SysV argument registers at
# FUNCTION ENTRY rather than named locals:
#
#   subreg_get_info (unsigned int xregno, machine_mode xmode,
#                    poly_int<2,ulong> offset, machine_mode ymode,
#                    subreg_info *info)
#      edi = xregno   esi = xmode   rdx = offset   ecx = ymode
#
# The LAST line printed before the SIGFPE is the faulting call.  A breakpoint
# that prints and continues is used rather than a conditional one because the
# condition would have to name a parameter this binary does not describe.
#
# NON-VACUITY: if the trace is empty the script says so and refuses to score;
# an empty trace and "the breakpoint never matched" look identical otherwise.
set -u
D=${1:?build dir}
T=${2:-powerpc64-unknown-linux-gnu}
IN=${3:?input}
S=$(cd "$(dirname "$0")" && pwd)
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config | head -1)
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }
O=$D/ta76-gdb; mkdir -p "$O"

cat > "$O/fpe.gdb" <<'EOF'
set confirm off
set pagination off
set height 0
set auto-load safe-path /
break subreg_get_info
commands
silent
printf "ENTER xregno=%u xmode=%u ymode=%u\n", $edi, $esi, $ecx
continue
end
run
echo \n===== STOPPED =====\n
bt 4
quit
EOF

sh "$S/eb-shell.sh" "cd $D/gcc && timeout 900s gdb -batch -x $O/fpe.gdb \
  --args ./cc1 -quiet -nostdinc -O2 -ftarget-config=$CFG $IN -o $O/fpe.s" \
  > "$O/fpe.out" 2> "$O/fpe.err"
n=$(grep -c '^ENTER ' "$O/fpe.out" || true)
echo "subreg_get_info entries traced: $n"
[ "$n" -ge 1 ] || { echo "FATAL: traced nothing -- not scoring"; exit 9; }
echo "--- LAST 5 ENTRIES (the last is the faulting call):"
grep '^ENTER ' "$O/fpe.out" | tail -5
echo "--- distinct xregno values seen:"
grep '^ENTER ' "$O/fpe.out" | sed 's/.*xregno=\([0-9]*\) .*/\1/' | sort -n | uniq -c | tail -5
echo "--- tail of gdb output:"
grep -v '^ENTER ' "$O/fpe.out" | tail -20
