#!/bin/sh
# Which target passes are inserted MORE THAN ONCE by one back end?
#
# Those are exactly the passes for which pass_manager's NEXT_PASS macro takes
# its `clone ()' arm for instance 2..N.  Instance 1 comes from the generated
# `make_<pass>_mt_<base>' forwarder, which sets `mt_base'; a clone comes from
# the back end's own `clone ()' override, which calls the RAW factory and
# therefore produces a pass with `mt_base == NULL' -- i.e. an UNOWNED pass,
# which `pass_owner_selected_p ()' lets run for every configured back end.
#
# Non-vacuity: the script FAILS if it finds no *-passes.def files at all, so
# "no multi-instance passes" cannot be confused with "nothing was scanned".
set -e
cd "$(dirname "$0")/.."
n=0
for f in gcc/config/*/*-passes.def; do
  [ -e "$f" ] || continue
  n=$((n + 1))
  b=$(basename "$(dirname "$f")")
  sed -n 's/^[ \t]*INSERT_PASS_\(AFTER\|BEFORE\)[ \t]*(\([^,]*\),[ \t]*[0-9]*,[ \t]*\([A-Za-z0-9_]*\).*/\3/p' "$f" \
    | sort | uniq -c \
    | awk -v b="$b" '$1 > 1 { print b, "\t", $1, "instances\t", $2 }'
done
if [ "$n" -eq 0 ]; then
  echo "FATAL: scanned 0 *-passes.def files -- the glob found nothing." >&2
  exit 9
fi
echo "(scanned $n back-end passes.def files)"
