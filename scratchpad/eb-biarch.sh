#!/bin/sh
# Two-sided proof that config.gcc's renamed reader (`enable_backends = all')
# still fires.  config.gcc:2131 adds TARGET_BI_ARCH=1 and i386/t-linux64 to
# i[34567]86-*-linux* ONLY when the variable reads literally `all'.
#
# Refuses to score if the stanza is missing or empty -- an empty extraction
# would make both sides look alike, which is the failure this is testing for.
show () {
  m=$1; tag=$2
  if test ! -f "$m"; then echo "$tag: NO MANIFEST at $m"; return 1; fi
  s=`awk '/^target i686-pc-linux-gnu$/{f=1} f&&/^$/{exit} f' "$m"`
  if test x"$s" = x; then echo "$tag: i686-pc-linux-gnu stanza NOT FOUND -- cannot score"; return 1; fi
  printf '%-10s TARGET_BI_ARCH=1 : ' "$tag"
  echo "$s" | grep -q 'TARGET_BI_ARCH=1' && echo yes || echo no
  printf '%-10s i386/t-linux64   : ' "$tag"
  echo "$s" | grep '^tmake_file ' | grep -q 'i386/t-linux64' && echo yes || echo no
}
show "$1" WITH-all
show "$2" NO-all
