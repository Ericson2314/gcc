#!/bin/sh
# Configuration-independent revocation check, because TMSET is not.
#
# TMSET was derived from i386-linux's tm.h, so it can only see macros THAT
# chain defines.  config/mingw/msformat-c.cc's `#ifdef TARGET_OVERRIDES_FORMAT_INIT'
# is defined in config/mingw/mingw32.h and is invisible to it -- the instrument
# scored that file CLEAR and it is not.  So ask the question in a form that
# does not depend on which back end happens to be configured: is any
# conditional identifier in a VESTIGIAL file `#define'd ANYWHERE under
# gcc/config/ (i.e. is it a tm.h-chain macro for SOME target)?
#
# Deliberately over-broad.  It can only REVOKE, never clear, so a false
# positive costs one unremoved include and a false negative costs correctness.
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc" || exit 9
awk '$1=="VESTIGIAL"{print $3}' "$W/wk/probe-results.txt" | while read -r f; do
  ids=$(grep -E '^[ 	]*#[ 	]*(if|ifdef|ifndef|elif)' "$f" \
        | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | grep -vx defined | sort -u)
  hit=
  for id in $ids; do
    if grep -rqE "^[ 	]*#[ 	]*define[ 	]+$id\b" config/; then hit="$hit $id"; fi
  done
  if [ -n "$hit" ]; then printf 'REVOKED  %-32s %s\n' "$f" "$hit"
  else printf 'CLEAR    %s\n' "$f"; fi
done
