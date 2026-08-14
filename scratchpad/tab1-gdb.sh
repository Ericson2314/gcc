#!/bin/sh
# Run cc1 UNDER gdb (never `gdb -p': this host's ptrace_scope refuses attaching
# to a non-descendant, and the failure reads as "the site is unlocated").
#
# gdb disables ASLR, and the mips fault is ASLR-sensitive, so this arm may
# simply not fault -- THAT IS A RESULT, not a failed run, and the script says
# so rather than printing an empty backtrace.
#
# usage: tab1-gdb.sh <builddir> <triple> <input.c> <-O level> [runs]
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; T=${2:?triple}; IN=${3:?input}; OPT=${4:--O2}; N=${5:-4}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }
O=$D/tab1-gdb; mkdir -p "$O"
cat > "$O/cmds" <<'EOF'
set confirm off
set pagination off
handle SIGSEGV stop nopass
run
echo \n==== BACKTRACE\n
bt 12
echo \n==== FRAME\n
frame 0
info locals
echo \n==== cfun\n
p cfun
p cfun->curr_properties
EOF
i=0
while [ "$i" -lt "$N" ]; do
  i=$((i+1))
  sh "$S/eb-shell.sh" "cd $D/gcc && ASAN_OPTIONS=detect_leaks=0:handle_segv=0 \
    timeout 900s gdb -batch -x $O/cmds --args ./cc1 -quiet -nostdinc $OPT \
    -ftarget-config=$CFG $IN -o $O/$T.$i.s" > "$O/$T.$i.gdb" 2>&1
  echo "run $i: rc=$? $(grep -m1 'Program received signal\|internal compiler error' "$O/$T.$i.gdb" | cut -c1-70)"
done
