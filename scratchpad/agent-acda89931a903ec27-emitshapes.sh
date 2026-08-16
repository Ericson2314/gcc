#!/bin/sh
# Every `ts_expected' key, and the SHAPE of the line that emits it.
#
# The pinning change rewrites each emission line so provenance is derived
# rather than hand-listed.  A mechanical rewrite that silently skips the lines
# it does not recognise would leave those keys with NO provenance record while
# the file looked complete -- the same "matched too little" failure as the
# REGNO sed, which matched nothing and was indistinguishable from a clean
# tree.  So the shapes are enumerated FIRST and every key must land in one.
set -u
AC=${1:-target-specs/configure.ac}
KEYS=$(awk '/^ts_expected="/,/"$/' "$AC" | sed 's/ts_expected="//; s/"$//' \
       | tr -s ' \n' '\n' | grep . | sort -u)
n=0; nb=0; nk=0; nu=0; nm=0
for k in $KEYS; do
  nk=$((nk+1))
  line=$(grep -nE "^$k( |\$)" "$AC" | head -1)
  if [ -z "$line" ]; then
    printf '%-40s NO-EMISSION-LINE\n' "$k"; nm=$((nm+1)); continue
  fi
  body=$(echo "$line" | sed 's/^[0-9]*://')
  case $body in
    "$k \`ts_bool \"\$"*"\"\`")  n=$((n+1)) ;;
    "$k \`"*)                    printf '%-40s OTHER-BACKTICK  %s\n' "$k" "$body"; nb=$((nb+1)) ;;
    *)                           printf '%-40s OTHER           %s\n' "$k" "$body"; nu=$((nu+1)) ;;
  esac
done
echo
echo "keys=$nk  ts_bool-conforming=$n  other-backtick=$nb  other=$nu  no-line=$nm"
[ $((n+nb+nu+nm)) -eq "$nk" ] || { echo "FATAL: shapes do not partition the key set"; exit 9; }
