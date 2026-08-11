#! /bin/sh
# Script to generate SYSROOT_SUFFIX_SPEC equivalent to MULTILIB_OSDIRNAMES
# Arguments are MULTILIB_OSDIRNAMES, MULTILIB_OPTIONS, MULTILIB_MATCHES,
# and MULTILIB_REUSE.

# Copyright (C) 2009-2026 Free Software Foundation, Inc.

# This file is part of GCC.

# GCC is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.

# GCC is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.

# You should have received a copy of the GNU General Public License
# along with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.  

# This shell script produces a header file fragment that defines
# SYSROOT_SUFFIX_SPEC.  It assumes that the sysroots will have the same
# structure and names used by the multilibs.

# Invocation:
#   print-sysroot-suffix.sh \
#          MULTILIB_OSDIRNAMES \
#          MULTILIB_OPTIONS \
#          MULTILIB_MATCHES \
#          MULTILIB_REUSE
#      > t-sysroot-suffix.h

# The four options exactly correspond to the variables of the same
# names defined in the t-sysroot-suffix tmake_file fragment.

# Example:
#   sh ./gcc/config/print-sysroot-suffix.sh "a=A" "a b/c/d" ""
# =>
#   #undef SYSROOT_SUFFIX_SPEC
#   #define SYSROOT_SUFFIX_SPEC "" \
#   "%{a:" \
#     "%{b:A/b/;" \
#     "c:A/c/;" \
#     "d:A/d/;" \
#     ":A/};" \
#   ":}"

# The script uses temporary subscripts in order to permit a recursive
# algorithm without the use of functions.

# Those subscripts go in a directory of this process's own.  They used to be
# written into the current directory under fixed names, which is fine for the
# one invocation a single-target build makes, but a multi-target build makes
# one per configured target and runs them in parallel: two copies then
# overwrite each other's helper mid-execution and the build dies with
# `$tmpdir/print-sysroot-suffix3.sh: Text file busy' and status 126.  A fixed name in
# a shared directory is the bug; $$ is unique per process and needs no mktemp.

set -e

tmpdir=./pss-tmp-$$
rm -rf "$tmpdir"
mkdir "$tmpdir"
trap 'rm -rf "$tmpdir"' 0

dirnames="$1"
options="$2"
matches="$3"
reuse="$4"

cat > $tmpdir/print-sysroot-suffix3.sh <<\EOF
#! /bin/sh
# Print all the multilib matches for this option
result="$1"
EOF
for x in $matches; do
  l=`echo $x | sed -e 's/=.*$//' -e 's/?/=/g'`
  r=`echo $x | sed -e 's/^.*=//' -e 's/?/=/g'`
  echo "[ \"\$1\" = \"$l\" ] && result=\"\$result|$r\"" >> $tmpdir/print-sysroot-suffix3.sh
done
echo 'echo $result' >> $tmpdir/print-sysroot-suffix3.sh
chmod +x $tmpdir/print-sysroot-suffix3.sh

cat > $tmpdir/print-sysroot-suffix2.sh <<\EOF
#! /bin/sh
# Recursive script to enumerate all multilib combinations, match against
# multilib directories and output a spec string of the result.
# Will fold identical trees.

padding="$1"
optstring="$2"
shift 2
n="\" \\
$padding\""
if [ $# = 0 ]; then
  case $optstring in
EOF
for x in $reuse; do
  l=`echo $x | sed -e 's/=.*$//' -e 's/\./=/g'`
  r=`echo $x | sed -e 's/^.*=//' -e 's/\./=/g'`
  echo "/$r/) optstring=\"/$l/\" ;;" >> $tmpdir/print-sysroot-suffix2.sh
done
echo "  esac" >> $tmpdir/print-sysroot-suffix2.sh

pat=
for x in $dirnames; do
  p=`echo $x | sed -e 's,=!,/$=/,'`
  pat="$pat -e 's=^//$p='"
done
echo '  optstring=`echo "/$optstring" | sed '"$pat\`" >> $tmpdir/print-sysroot-suffix2.sh
cat >> $tmpdir/print-sysroot-suffix2.sh <<\EOF
  case $optstring in
  //*)
    ;;
  *)
    echo "$optstring"
    ;;
  esac
else
  thisopt="$1"
  shift
  bit=
  lastcond=
  result=
  for x in `echo "$thisopt" | sed -e 's,/, ,g'`; do
    case $x in
EOF
for x in `echo "$options" | sed -e 's,/, ,g'`; do
  match=`$tmpdir/print-sysroot-suffix3.sh "$x"`
  echo "$x) optmatch=\"$match\" ;;" >> $tmpdir/print-sysroot-suffix2.sh
done
cat >> $tmpdir/print-sysroot-suffix2.sh <<\EOF
    esac
    bit=`"$0" "$padding  " "$optstring$x/" "$@"`
    if [ -z "$lastopt" ]; then
      lastopt="$optmatch"
    else
      if [ "$lastbit" = "$bit" ]; then
	lastopt="$lastopt|$optmatch"
      else
	result="$result$lastopt:$lastbit;$n"
	lastopt="$optmatch"
      fi
    fi
    lastbit="$bit"
  done
  bit=`"$0" "$padding  " "$optstring" "$@"`
  if [ "$bit" = "$lastbit" ]; then
    if [ -z "$result" ]; then
      echo "$bit"
    else
      echo "$n%{$result:$bit}"
    fi
  else
    echo "$n%{$result$lastopt:$lastbit;$n:$bit}"
  fi
fi
EOF

chmod +x $tmpdir/print-sysroot-suffix2.sh
result=`$tmpdir/print-sysroot-suffix2.sh "" "/" $options`
echo "#undef SYSROOT_SUFFIX_SPEC"
echo "#define SYSROOT_SUFFIX_SPEC \"$result\""
