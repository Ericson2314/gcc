#!/bin/sh
# #173 -- THE INSTRUMENT FOR A SILENT CHANGE.
#
# Deleting `-I<base>-inc' does NOT fail loudly: 15 of the 16 per-back-end
# stems also exist under their plain name in the build root (t173-rootstems.sh),
# so an unconverted include silently starts reading the build root's copy --
# the union for some stems, the PRIMARY BACK END's header for others.  A build
# log cannot see that.  The dependency files can: every header a compilation
# actually opened is listed in .deps/<obj>.Po, by path.
#
# Emits, per object, the sorted set of `<base>-inc/...' headers it opened.
# Diffing that between the before and after trees names every site the -I was
# deciding.  An object whose <base>-inc entries VANISH is one that silently
# fell back to the build root.
set -e
D=${1:?build dir}
cd "$D/gcc"
find . -name '*.Po' -o -name '*.TPo' | sort | while read -r p; do
  tr ' \\' '\n\n' < "$p" | grep -- '-inc/' | sed 's|^\./||' | sort -u \
    | sed "s|^|$(echo "$p" | sed 's|^\./||') |"
done
