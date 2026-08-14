#!/bin/sh
# #173 -- the Kind A list: the UNION of the A verdicts over every build dir
# given, because A is a property of the file and N is a property of the
# CONFIGURATION.  loongarch-c.cc scores N in the 47-back-end build (loongarch
# is not in backends-47.txt) and A in the OS build; sol2-c.cc scores N in
# both, and that is not evidence it is per-base somewhere -- it is settled
# from gen-multi-target-md.awk instead, which only takes c_target_objs that
# live under config/<cpu>/.
set -e
S=$(cd "$(dirname "$0")" && pwd)
: > /tmp/t173-a.txt
for d in "$@"; do
  case "$d" in
    /tmp/b-a7d1e0-base) ml=40 ;;
    *) ml=10 ;;
  esac
  MINLIST=$ml sh "$S/t173-classify.sh" "$d" | awk '$2 == "A" { print $1 }' \
    >> /tmp/t173-a.txt
done
sort -u /tmp/t173-a.txt | sed 's|^|gcc/config/|'
