#!/bin/sh
# Compile scratchpad/mtsw-size-probe.cc in every context that matters and
# print, per symbol, the value each context measured.
#
# The compile commands are LIFTED FROM THE BUILD'S OWN LOG rather than
# reconstructed: a probe compiled with flags that differ from the real objects
# is measuring a fourth context nobody ships.  The shared arm reuses the
# command line make used for reginfo.o (the consumer side of the layout
# check); each per-base arm reuses target-regs-<base>.o's (the supply side).
#
# A context whose object fails to compile, or whose `nm -S' reports no symbol,
# is FATAL: an absent reading must never be able to look like agreement.
#
# usage: mtsw-probe-run.sh <builddir> <buildlog> <base>...
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}; shift
LOG=${1:?build log}; shift
[ $# -gt 0 ] || { echo "FATAL: no bases given"; exit 9; }

# The build dir must be this worktree's, by its own testimony.
grep -q "$SRC" "$D/gcc/config.log" \
  || { echo "FATAL: $D/gcc/config.log does not name $SRC"; exit 9; }

WORK=$D/mtsw-probe
rm -rf "$WORK"; mkdir -p "$WORK"

extract () { # <object name> -> the whole compile command, continuations joined
  # make echoes some recipes across several lines with a trailing backslash;
  # taking only the first line silently drops the source file and every flag
  # after it, which then fails as `linker input file not found'.
  awk -v pat="-o $1 " '
    index ($0, pat) && !done { inrec = 1 }
    inrec {
      line = $0
      if (sub (/\\$/, "", line)) { printf "%s ", line }
      else { printf "%s\n", line; inrec = 0; done = 1 }
    }' "$LOG"
}

run_ctx () { # <label> <template object> <extra flags>
  label=$1; tmpl=$2; extra=$3
  cmd=$(extract "$tmpl")
  [ -n "$cmd" ] || { echo "FATAL: no compile line for $tmpl in $LOG"; exit 9; }
  # Drop the trailing source file, the -o, and the dependency-file options:
  # everything else (the -I list, the -D list) is what defines the context.
  cmd=$(echo "$cmd" \
	| sed -e 's,-o [^ ]*\.o ,,' \
	      -e 's,-MT [^ ]*,,' -e 's,-MMD,,' -e 's,-MP,,' \
	      -e 's,-MF [^ ]*,,' \
	      -e 's,[^ ]*\.cc\( \|$\), ,g')
  ( cd "$D/gcc" && sh -c "$cmd $extra -o $WORK/$label.o $S/mtsw-size-probe.cc" ) \
    > "$WORK/$label.err" 2>&1 \
    || { echo "FATAL: probe did not compile in context $label:"; \
	 cat "$WORK/$label.err"; exit 9; }
}

run_ctx shared reginfo.o ""
for b in "$@"; do
  run_ctx "$b" "target-regs-$b.o" ""
done

NM=${NM:-nm}
read_sizes () { # <label>
  $NM -S "$WORK/$1.o" | awk '$4 ~ /^mtsw_/ { print $4, strtonum("0x" $2) - 1 }' \
    | sort
}

for l in shared "$@"; do
  read_sizes "$l" > "$WORK/$l.txt"
  n=$(wc -l < "$WORK/$l.txt")
  [ "$n" -gt 20 ] || { echo "FATAL: context $l yielded only $n symbols"; exit 9; }
done

printf '%-36s' symbol; for l in shared "$@"; do printf '%12s' "$l"; done; echo
awk '{print $1}' "$WORK/shared.txt" | while read -r sym; do
  line=$(printf '%-36s' "$sym")
  first=; diff=no
  for l in shared "$@"; do
    v=$(awk -v s="$sym" '$1 == s {print $2}' "$WORK/$l.txt")
    [ -n "$v" ] || { echo "FATAL: $l has no $sym"; exit 9; }
    if [ -z "$first" ]; then first=$v; elif [ "$v" != "$first" ]; then diff=yes; fi
    line="$line$(printf '%12s' "$v")"
  done
  [ "$diff" = no ] || line="$line   <== DIVERGES"
  echo "$line"
done
