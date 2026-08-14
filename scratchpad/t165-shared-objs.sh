#!/bin/sh
# #165 Part B -- WHICH config/ SOURCES ARE COMPILED FOR MORE THAN ONE BACK END?
#
# This is the shape behind every collision found so far.  `config/linux.cc',
# `config/arm/aarch-common.cc' and `config/arm/aarch-bti-insert.cc' are each
# compiled once per base that claims them, so every bare global they define is
# defined N times in one `cc1'.  The linker diagnoses only the subset whose
# archive members are both pulled in (T157-STUBS.md), so the SOURCE-level
# question is the one that can be asked ahead of a build -- and ahead of
# configuring the back end at all, which is the point for Part B.
#
# Instrument: `extra_objs' in config.gcc, per cpu case.  Deliberately
# over-broad in the same way as t165-macrotest.sh's arm M -- it lists
# candidates for the rename list, it does not authorise anything.
#
# usage: t165-shared-objs.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G" || exit 9

[ -f config.gcc ] || { echo "REFUSING TO SCORE: no config.gcc in $G"; exit 9; }

# obj -> list of cpu dirs claiming it.  A cpu is attributed from the enclosing
# `<cpu>-*-*)' case label, which is what config.gcc keys extra_objs on.
awk '
  # case labels look like  aarch64*-*-elf | aarch64*-*-fuchsia* ...)
  /^[a-z0-9_]+[*-]/ && /\)$/ {
    lab = $0; sub(/\).*/, "", lab)
    split(lab, a, /[|]/)
    cpu = a[1]; gsub(/[ \t]/, "", cpu); sub(/[*-].*/, "", cpu)
    cur = cpu
  }
  /extra_objs=/ {
    line = $0
    sub(/.*extra_objs="?/, "", line); sub(/".*/, "", line)
    n = split(line, o, /[ \t]+/)
    for (i = 1; i <= n; i++)
      if (o[i] ~ /\.o$/ && cur != "") {
        if (index(" " seen[o[i]] " ", " " cur " ") == 0)
          seen[o[i]] = seen[o[i]] " " cur
      }
  }
  END {
    for (k in seen) {
      c = split(seen[k], t, /[ \t]+/)
      nn = 0; for (i=1;i<=c;i++) if (t[i] != "") nn++
      if (nn > 1) printf "%-34s %s\n", k, seen[k]
    }
  }
' config.gcc | sort

echo
echo "== config/*.cc (no cpu dir): compiled for EVERY base that includes them"
ls *.cc 2>/dev/null | sed 's/^/  /' || true
ls config/*.cc | sed 's|^|  |'
