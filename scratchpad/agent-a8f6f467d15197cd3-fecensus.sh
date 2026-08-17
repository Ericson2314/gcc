#!/bin/sh
# agent-a8f6f467d15197cd3-fecensus.sh -- the OTHER front ends: do they carry
# `tm.h', do they spell target macros, and has any of them ever been built
# multi-target?
#
# WHY.  C++ had never been built on this branch until three agents ago -- one
# hardcoded `--enable-languages=c,lto' in mt-conf.sh decided that, silently --
# and the first look found an ABI-incompatible pointer-to-member-function on
# eight back ends at rc=0.  A language never enabled and a language passing
# everything produce the SAME EMPTY FAILURE LIST, so the deliverable here is
# which front ends have ZERO coverage, stated by name.
#
# Three columns, three DIFFERENT questions, deliberately not collapsed:
#   TM-CHANNEL   does any source or header in the directory reach `tm.h'
#                (spelled directly, or via MT_HEADER/BASE_HEADER)?
#   SURFACE      how many names from the target-macro vocabulary does it
#                spell?  (agent-a8f6f467d15197cd3-cxxsurface.sh's intersection)
#   ENABLED-EVER has any build dir on this host ever configured it?
#
# The third is read from the BUILD DIRS' own testimony -- each
# `config.log' records the `--enable-languages' configure ran with -- and not
# from anybody's memory.  A directory with a big SURFACE and ENABLED-EVER=no
# is the C++ situation exactly.
set -eu
S=${1:?srcdir}
S=$(cd "$S" && pwd)
cd "$S/gcc"

FES='c c-family cp objc objcp lto d fortran rust go ada m2 jit analyzer'

# ---- the target-macro vocabulary, HEADERS ONLY --------------------------
# Headers only, because the `tm.h' chain is headers: a `#define' inside a
# back end's .cc file is that file's private macro and cannot reach a front
# end.  Including .cc files put `C', `A', `OP', `BASE', `ENTRY', `STR' and
# `FUNCTION' into an earlier run of this census -- macro PARAMETERS in
# rl78.cc and the SVE builtins headers -- which is noise at the top of a
# ranking, i.e. the expensive place.
grep -rhE '^[[:space:]]*#[[:space:]]*define[[:space:]]+[A-Za-z_][A-Za-z_0-9]*' \
     --include='*.h' --include='*.def' config/ defaults.h 2>/dev/null \
  | sed -E 's/^[[:space:]]*#[[:space:]]*define[[:space:]]+([A-Za-z_][A-Za-z_0-9]*).*/\1/' \
  | sort -u > /tmp/fec-vocab.$$
NV=$(wc -l < /tmp/fec-vocab.$$)
grep -qx BITS_PER_WORD /tmp/fec-vocab.$$ || { echo "REFUSE: vocabulary control absent"; exit 9; }
[ "$NV" -ge 3000 ] || { echo "REFUSE: vocabulary $NV names"; exit 9; }
echo "target-macro vocabulary (headers under config/ + defaults.h): $NV names"
echo

# ---- ENABLED-EVER: read from the BUILD DIRS' OWN TESTIMONY --------------
# Each build dir's config.log records the `--enable-languages' its configure
# actually ran with.  That instrument is independent of any script by
# construction and survives the scripts being repaired afterwards -- the same
# argument PRINCIPLES makes for `built-tree-audit.sh'.  Read the TOP-LEVEL
# config.log, not gcc/config.log: the top level is where the flag was typed.
: > /tmp/fec-langs.$$
: > /tmp/fec-bd.$$
# NOT `for ... done | sort': a `for' loop piped into anything runs in a
# SUBSHELL, so `nb' increments there and is 0 in the parent.  This script's
# first run refused with `no build dir readable' on the line immediately
# after printing the languages it had read out of them -- the counter and the
# data disagreeing because only one of them crossed the pipe.  Recorded
# rather than quietly fixed: it is the shape where a REFUSAL fires on a
# healthy tree, which is the direction that wastes a day.
for b in /tmp/b-*/config.log; do
  [ -r "$b" ] || continue
  echo "$b" >> /tmp/fec-bd.$$
  sed -n "s/.*--enable-languages=\([A-Za-z0-9,+-]*\).*/\1/p" "$b" | tr ',' '\n' \
    >> /tmp/fec-langs.$$
done
sort -u -o /tmp/fec-langs.$$ /tmp/fec-langs.$$
nb=$(grep -c . /tmp/fec-bd.$$ || true)
echo "build dirs readable on this host: $nb"
echo "languages any of them was configured with: $(grep . /tmp/fec-langs.$$ | tr '\n' ' ')"
echo "NOTE: this reads only build dirs STILL ON DISK.  A language absent here"
echo "      is 'no surviving build dir enabled it', which is a LOWER bound on"
echo "      coverage; the committed-harness arm below is the independent one."
if [ "$nb" = 0 ]; then
  # A zero here is NOT "no language was ever enabled"; it is "this instrument
  # read nothing".  Those are the two readings PRINCIPLES says must never
  # produce the same output, so it refuses rather than scoring.
  echo "REFUSE: no /tmp/b-*/config.log readable -- cannot distinguish"
  echo "        'never enabled' from 'never measured'.  Build first."
  exit 9
fi

# ---- the INDEPENDENT arm: what the COMMITTED harness can even ask for ----
# Build dirs get deleted; the harness is in git.  Every board on this branch
# is configured through mt-conf.sh, so its MT_LANGUAGES default plus every
# committed spelling of --enable-languages/MT_LANGUAGES bounds what any past
# board COULD have covered, whether or not its build dir survives.
echo
echo "committed harness -- every --enable-languages / MT_LANGUAGES spelling:"
grep -rhoE '(MT_LANGUAGES|--enable-languages)=[A-Za-z0-9,+${}:_-]*' \
     "$S/scratchpad" "$S/gcc/Makefile.in" "$S/configure.ac" 2>/dev/null \
  | sort | uniq -c | sort -rn | sed 's/^/  /'
echo

printf '%-10s %6s %-12s %8s %-12s %s\n' DIR files TM-CHANNEL surface ENABLED-EVER 'top names by definer count'
for d in $FES; do
  [ -d "$d" ] || { printf '%-10s %6s %-12s %8s %-12s %s\n' "$d" - ABSENT - - '(no such directory)'; continue; }
  find "$d" -name '*.cc' -o -name '*.h' -o -name '*.c' -o -name '*.cpp' > /tmp/fec-f.$$
  nf=$(wc -l < /tmp/fec-f.$$)
  if [ "$nf" = 0 ]; then
    printf '%-10s %6s %-12s %8s %-12s %s\n' "$d" 0 none 0 - '(no C/C++ sources)'; continue
  fi
  # TM-CHANNEL: three spellings, because #174 removed -I<base>-inc and the
  # macro forms are invisible to a grep for the quoted string.
  tm=$(grep -lE '"tm\.h"|MT_HEADER *\( *tm\.h *\)|BASE_HEADER *\( *tm\.h *\)' \
        $(cat /tmp/fec-f.$$) 2>/dev/null | tr '\n' ' ')
  [ -n "$tm" ] && ch=$(echo "$tm" | wc -w) || ch=0
  grep -hvE '^[[:space:]]*#[[:space:]]*(define|undef)[[:space:]]' $(cat /tmp/fec-f.$$) 2>/dev/null \
    | grep -ohE '\<[A-Za-z_][A-Za-z_0-9]*\>' | sort -u > /tmp/fec-u.$$
  comm -12 /tmp/fec-vocab.$$ /tmp/fec-u.$$ > /tmp/fec-h.$$
  nh=$(wc -l < /tmp/fec-h.$$)
  # Rank by DEFINER COUNT, not alphabetically.  An alphabetical head puts
  # `bool', `f1', `f2' and `ENTRY' at the top of every row -- names some
  # config header happens to define -- and buries the divergent ones, which
  # is noise in the one place a ranking is read.
  : > /tmp/fec-r.$$
  while read -r m; do
    dc=$(grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\>" \
          --include='*.h' --include='*.def' config/ defaults.h 2>/dev/null | sort -u | wc -l)
    [ "$dc" -ge "${MIN_DEFINERS:-5}" ] && echo "$dc $m" >> /tmp/fec-r.$$
  done < /tmp/fec-h.$$
  top=$(sort -k1,1nr /tmp/fec-r.$$ | head -8 | awk '{printf "%s(%s) ", $2, $1}')
  # ENABLED-EVER: the front-end DIRECTORY name is not the --enable-languages
  # spelling for two of them (cp -> c++, objcp -> obj-c++), so map rather
  # than match, or C++ scores `no' on a build that enabled it.
  case $d in
    cp) lang=c++ ;; objcp) lang=obj-c++ ;; c-family|analyzer) lang='(always)' ;;
    ada) lang=ada ;; m2) lang=m2 ;; *) lang=$d ;;
  esac
  if [ "$lang" = '(always)' ]; then ev='n/a'
  elif grep -qx "$lang" /tmp/fec-langs.$$; then ev=yes
  else ev='NO'; fi
  printf '%-10s %6s %-12s %8s %-12s %s\n' "$d" "$nf" "${ch} file(s)" "$nh" "$ev" "$top"
  echo "$tm" | tr ' ' '\n' | grep . | sed 's/^/               tm.h: /' || true
done
rm -f /tmp/fec-vocab.$$ /tmp/fec-f.$$ /tmp/fec-u.$$ /tmp/fec-h.$$ /tmp/fec-r.$$ /tmp/fec-langs.$$
