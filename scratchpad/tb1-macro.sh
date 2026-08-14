#!/bin/sh
# #163 -- what does `HAVE_AS_TLS' expand to, in a named object of a real
# build?  One arm, usable on a pre-#163 and a post-#163 tree, so the two can
# be put side by side.  Same `-E -dM' off the object's own recipe as
# tb1-itc.sh, for the same reason: `<ABSENT>' and `0' must not be the same
# reading.
#
# usage: tb1-macro.sh <builddir> <object> [macro ...]
set -u
D=${1:?build dir}
O=${2:?object}
shift 2
WANT=${*:-HAVE_AS_TLS HAVE_AS_DTPREL_RELOC}
case "$D" in
  */b-agent-aab545de8b02de843*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D/make-top.rc absent -- unstamped log"; exit 9; }
S=$(cd "$(dirname "$0")" && pwd)
LOG="$D/tb1-joined.log"
awk '{ if (buf != "") $0 = buf " " $0; if (sub(/\\$/, "")) { buf = $0; next } buf = ""; print }' \
  "$D/make-top.out" > "$LOG"
cmd=$(grep -F -- " -o $O " "$LOG" | tail -1)
[ -n "$cmd" ] || { echo "FATAL: no compile command for $O"; exit 9; }
pp=$(printf '%s\n' "$cmd" | sed -e 's/ -c / /' -e 's/ -o [^ ]*//' \
       -e 's/ -MT [^ ]*//' -e 's/ -MF [^ ]*//' -e 's/ -MMD//' -e 's/ -MP//')
{ echo "cd $D/gcc"; printf '%s -E -dM\n' "$pp"; } > "$D/tb1-macro-pp.sh"
out=$(sh "$S/eb-shell.sh" "sh $D/tb1-macro-pp.sh" 2>/dev/null || true)
n=$(printf '%s\n' "$out" | grep -c '^#define ' || true)
[ "$n" -ge 500 ] || { echo "FATAL: recovered $n macros; the run did not preprocess"; exit 9; }
echo "$D  $O  ($n macros)"
for m in $WANT; do
  v=$(printf '%s\n' "$out" | awk -v m="$m" '$1=="#define" && $2==m {$1="";$2="";print substr($0,3); f=1} END{if(!f) print "<ABSENT>"}')
  printf '    %-24s %s\n' "$m" "$v"
done
