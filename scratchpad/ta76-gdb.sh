#!/bin/sh
# Run `cc1' for ONE configured back end UNDER gdb and report where it stops.
#
# WHY UNDER gdb RATHER THAN `gdb -p'.  #a9f could not locate mips's spin site
# because `gdb -p' returned `ptrace: Operation not permitted' -- this host's
# yama ptrace_scope forbids attaching to a process that is not a descendant.
# Launching the inferior FROM gdb makes it a descendant, so the restriction
# does not apply, and it works for a hang as well as for a crash: gdb's own
# SIGALRM-driven interrupt is not available, so the hang arm uses a shell
# `timeout' sending SIGINT to gdb, which stops the inferior and runs the
# batch commands that follow.
#
# The four targets with no cross binutils use the explicitly-labelled fallback
# config from ta76-nobinutils.sh; that config's ANSWERS are not trusted for
# anything, it exists so `cc1' can start at all.
#
# usage: ta76-gdb.sh <builddir> <canonical-triple> <input.c> <-O level> [seconds]
set -u
D=${1:?build dir}
T=${2:?triple}
IN=${3:?input}
OPT=${4:--O2}
SECS=${5:-60}
S=$(cd "$(dirname "$0")" && pwd)
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 in $D/gcc"; exit 9; }
CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }

O=$D/ta76-gdb; mkdir -p "$O"
tag=$T$(echo "$OPT" | tr -d ' -')

cat > "$O/$tag.gdb" <<'EOF'
set confirm off
set pagination off
set height 0
set auto-load safe-path /
handle SIGSEGV stop nopass
handle SIGFPE  stop nopass
run
echo \n===== STOPPED =====\n
bt 30
echo \n===== FRAME 0 =====\n
info frame
info registers rax rdi rsi rdx rcx
echo \n===== DISASSEMBLE =====\n
x/6i $pc
echo \n===== LOCALS (may be empty without -g) =====\n
info locals
quit
EOF

# `timeout -s INT' so that a HANG produces the same report a crash does.
sh "$S/eb-shell.sh" "cd $D/gcc && ${MT_ENV:-} timeout -s INT ${SECS}s gdb -batch -x $O/$tag.gdb \
  --args ./cc1 -quiet -nostdinc $OPT -ftarget-config=$CFG $IN -o $O/$tag.s" \
  > "$O/$tag.gdbout" 2> "$O/$tag.gdberr"
rc=$?
echo "=== $T $OPT  gdb rc=$rc  (124 = timed out, i.e. it was still running)"
cat "$O/$tag.gdbout"
echo "--- stderr:"
sed -n 1,20p "$O/$tag.gdberr"
