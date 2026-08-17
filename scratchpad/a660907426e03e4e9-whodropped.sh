#!/bin/sh
# Which commit dropped the `eh_return_stackadj' accessor pair?
#
# `5d1dd487000' ADDED a `target_frame_desc' member, two `extern' declarations
# in `target-frame.h' and their definitions in `target-cumargs{,-select}.cc',
# and it is an ANCESTOR of the tip -- yet the tip has the CALL SITES and none
# of the accessors, so `make all-gcc' dies with
#
#   c-cppbuiltin.cc:1638: error: `mt_has_eh_return_stackadj_rtx' was not
#   declared in this scope
#
# A merge diff only shows conflict RESOLUTIONS, so `git show <merge>' prints
# nothing for a side that was silently taken whole.  Read the FILE at each
# commit instead; that is the reading a merge cannot hide from.
set -u
for c in "$@"; do
  a=$(git show "$c:gcc/target-frame.h" 2>/dev/null | grep -c eh_return_stackadj)
  b=$(git show "$c:gcc/target-cumargs-select.cc" 2>/dev/null | grep -c eh_return_stackadj)
  d=$(git show "$c:gcc/except.cc" 2>/dev/null | grep -c mt_has_eh_return_stackadj_rtx)
  printf '%-14s target-frame.h=%-3s cumargs-select.cc=%-3s except.cc(uses)=%-3s %s\n' \
    "$c" "$a" "$b" "$d" "$(git log -1 --format=%s "$c" | cut -c1-58)"
done
