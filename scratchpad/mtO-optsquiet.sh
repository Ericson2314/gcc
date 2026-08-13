#!/bin/sh
# THE QUIET HALF OF CAUSE 8.
#
# mtN-optsleak.sh counts the macros a <cpu>-opts.h leaks into the shared
# options.h and that somebody else also defines.  Those produce the 958
# diagnostics only when the leaked expansion fails to PARSE in the other back
# end -- loongarch's `la_target.isa.base == ISA_BASE_LA64' does not.
#
# The dangerous cases are the ones that DO parse.  There are four, and only
# the first is loud:
#
#   LOUD          the other back end redefines M with different text.  cpp
#                 warns `M redefined'.  Every use BEFORE the redefinition
#                 still expanded to the leaked answer.
#   SILENT-IDENT  the other back end redefines M with TEXTUALLY IDENTICAL
#                 replacement.  A benign redefinition: no diagnostic at all,
#                 ever.  Correct by luck, and the luck is per-name.
#   SILENT-IFNDEF the other back end guards its own definition with
#                 `#ifndef M'.  options.h got there first, so the back end's
#                 OWN answer is discarded and there is no diagnostic.  This
#                 is the #ifndef-floor failure of PRINCIPLES 2a arriving from
#                 outside the file.
#   SILENT-UNDEF  the other back end does `#undef M' first.  Correct from that
#                 point on; uses before it are still the leaked answer.
#
# And a fifth population with no collision at all: a back end (or shared code)
# that USES M and never defines it.  Without the leak that is a compile error;
# with it, it silently reads another back end's macro.
#
# usage: mtO-optsquiet.sh <gcc-srcdir> <leaks.txt from mtO-optsmacro2.sh>
set -e
S=${1:?gcc srcdir}
L=${2:?leaks list}
[ -s "$L" ] || { echo "FATAL: $L is empty; nothing to classify"; exit 9; }
[ -d "$S/config" ] || { echo "FATAL: $S/config is not a directory"; exit 9; }

# A name AC_DEFINEd by gcc/configure.ac is settled before either header is
# read: auto-host.h comes in through config.h at the top of every translation
# unit, so its answer wins and BOTH #ifndef floors are dead.  Without this arm
# HAVE_AS_TLS scores as six back ends silently adopting loongarch's floor of 0,
# which is a real-looking finding and is wrong -- configure.ac AC_DEFINEs it to
# 1 unconditionally, so nobody's floor fires at all.  A classifier that only
# reads config/ cannot see that, and it fails in the alarming direction.
while IFS='	' read -r cpu kind m; do
  if grep -q "AC_DEFINE(\[\{0,1\}$m[,]\|AC_DEFINE_UNQUOTED(\[\{0,1\}$m[,]" "$S"/configure.ac; then
    printf 'AUTOHOST\t%s\t%s\t%s\n' "$m" "$cpu" gcc/configure.ac
    continue
  fi
  # Every config/ file other than cpu's own that defines M.
  files=$(grep -rl "^[ 	]*#[ 	]*define[ 	]\{1,\}$m\([^A-Za-z_0-9]\|\$\)" "$S"/config/ || true)
  for f in $files; do
    d=$(printf '%s' "$f" | sed "s|$S/config/||" | cut -d/ -f1)
    [ "$d" = "$cpu" ] && continue
    if grep -q "^[ 	]*#[ 	]*undef[ 	]\{1,\}$m\([^A-Za-z_0-9]\|\$\)" "$f"; then
      cls=SILENT-UNDEF
    elif grep -q "^[ 	]*#[ 	]*ifndef[ 	]\{1,\}$m\([^A-Za-z_0-9]\|\$\)" "$f"; then
      cls=SILENT-IFNDEF
    else
      # Identical replacement text?  Compare the first definition in each file.
      a=$(sed -n "s/^[ 	]*#[ 	]*define[ 	]\{1,\}$m\([^A-Za-z_0-9].*\)*\$/\1/p" \
            "$S"/config/"$cpu"/"$cpu"-opts.h | head -1)
      b=$(sed -n "s/^[ 	]*#[ 	]*define[ 	]\{1,\}$m\([^A-Za-z_0-9].*\)*\$/\1/p" "$f" | head -1)
      if [ "$a" = "$b" ]; then cls=SILENT-IDENT; else cls=LOUD; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$cls" "$m" "$cpu" "${f#"$S"/config/}"
  done
done < "$L"
