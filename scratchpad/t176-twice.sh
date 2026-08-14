#!/bin/sh
# #176 -- WHICH SOURCES ARE COMPILED IN MORE THAN ONE CONFIGURATION?
#
# THE DEFECT THIS EXISTS TO PREVENT, WHICH THIS TASK COMMITTED.  The
# amputation arm rebuilds an object with the `tm.h' line cut, using ONE real
# recipe -- `cfgexpand.o''s, i.e. a shared cc1 object.  `rtl.cc',
# `read-rtl.cc' and `print-rtl.cc' are ALSO compiled once per back end as
# generators (`build/rtl-<cpu>.o'), and a generator is a different
# configuration: `-DGENERATOR_FILE' makes `hard-reg-set.h:57' take its
# register widths from the RAW `tm.h' names rather than from
# `multi-target-reg-widths.h'.  All three scored DELETE-CLEAN on the shared
# recipe and produced 4272 diagnostics in the generator one -- 1536
# `FIRST_PSEUDO_REGISTER', 1296 `enum reg_class', 1296 `N_REG_CLASSES' -- from
# three deletions.
#
# The measurement was not wrong; it was answered for one configuration and
# read as if it covered every configuration the file is built in.  That is
# PRINCIPLES' "a test in a reduced environment can pass for a reason the real
# environment removes", and the reduced environment here was a RECIPE rather
# than a directory.
#
# So: before deleting a `tm.h' include, ask whether the file has a second
# compilation at all.  Anything this prints must be measured in BOTH
# configurations or left alone.
#
# usage: t176-twice.sh <builddir> [file-relative-to-gcc ...]
#        with no files, reports every such source in the tree.
set -e
R=$(cd "$(cd "$(dirname "$0")/.." && pwd)" && pwd)
D=${1:?build dir}; shift
[ -f "$D/gcc/Makefile" ] || { echo "FATAL: $D/gcc/Makefile missing"; exit 9; }

# Every `build/<stem>.o' the build system knows about, stem only.  The
# per-base generators are `build/<stem>-<cpu>.o', so strip a trailing -<cpu>.
grep -hoE 'build/[a-zA-Z0-9_-]+\.o' "$D/gcc/Makefile" "$D/gcc/multi-target-md.mk" 2>/dev/null \
  | sed 's|.*build/||; s|\.o$||' | sort -u > /tmp/t176-buildstems.txt
[ -s /tmp/t176-buildstems.txt ] || { echo "FATAL: no build/ objects found -- instrument is blind"; exit 9; }

if [ $# -eq 0 ]; then
  set -- $(cd "$R/gcc" && ls *.cc 2>/dev/null)
fi
n=0
for f in "$@"; do
  stem=$(basename "$f" .cc)
  # exact stem, or stem-<cpu> for the per-base generator copies
  if grep -qx "$stem" /tmp/t176-buildstems.txt \
     || grep -qE "^$stem-[a-z0-9]+\$" /tmp/t176-buildstems.txt; then
    printf 'TWICE  %-28s also built as build/%s*.o\n' "$f" "$stem"
    n=$((n + 1))
  fi
done
echo "sources compiled in more than one configuration: $n"
