#!/bin/sh
# #163 -- print the SOURCE CONTEXT of every non-.md HAVE_AS_TLS site, so the
# conversion is planned against the text rather than against a shape label.
set -e
cd "$(dirname "$0")/../gcc"
git grep -n '\bHAVE_AS_TLS\b' -- . ':(exclude)*ChangeLog*' ':(exclude)configure' \
    ':(exclude)*.md' ':(exclude)*CONFIGURE-HISTORY*' \
  | cut -d: -f1,2 | sort -u -t: -k1,1 -k2,2n \
  | while IFS=: read -r f l; do
      a=$((l-4)); [ "$a" -lt 1 ] && a=1
      b=$((l+6))
      echo "=== $f:$l"
      awk -v a="$a" -v b="$b" -v hit="$l" \
	  'NR>=a&&NR<=b{printf "%s%5d| %s\n", (NR==hit?">":" "), NR, $0}' "$f"
    done
