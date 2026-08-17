#!/bin/sh
# a94d141d788a6b54f-asflags.sh -- RE-ASSEMBLE ONE TARGET'S CORPUS WITH FLAGS.
#
# The corpus script invokes `<triple>-as' with NO FLAGS.  That is right for
# most targets and WRONG for any target whose `ASM_SPEC' carries something the
# assembler needs in order to parse the dialect the compiler emits.  `bpf' is
# the worked example: `config/bpf/bpf.h:28' passes `-mdialect=pseudoc' by
# default, and without it GNU as reads pseudo-C output in the `normal' dialect
# and reports `unrecognized instruction'.
#
# So this script exists to keep two verdicts apart that produce the SAME rc:
#
#   the compiler emitted assembly its own assembler rejects  (a real defect)
#   the harness invoked the assembler without the driver's own flags
#
# usage: a94d141d788a6b54f-asflags.sh <as-binary> <corpus-glob-prefix> [flags...]
# Exit 9 if it assembled nothing at all -- an empty sweep printing 0/0 is the
# null result this whole board is about.
set -u
AS=${1:?path to the cross as}
PRE=${2:?corpus file prefix, e.g. /tmp/corpus-.../bpf-unknown-none}
shift 2

[ -x "$AS" ] || { echo "FATAL: $AS is not executable"; exit 9; }
"$AS" --version >/dev/null 2>&1 \
  || { echo "FATAL: $AS does not EXECUTE -- a broken assembler and bad assembly give the same rc"; exit 9; }

n=0; ok=0
for f in "$PRE"-*.s; do
  [ -f "$f" ] || continue
  n=$((n + 1))
  if "$AS" "$@" -o "$f.flagged.o" "$f" > "$f.flagged.err" 2>&1; then
    ok=$((ok + 1))
    echo "AS-OK   $(basename "$f")"
  else
    echo "AS-BAD  $(basename "$f")   $(sed -n 2p "$f.flagged.err")"
  fi
done
echo "asflags: $AS $* -> $ok/$n"
[ "$n" -gt 0 ] || { echo "FATAL: no .s matched $PRE-*.s -- NULL RESULT, not a pass"; exit 9; }
