#!/bin/sh
# #51: the collision surface of the PRIMARY's un-namespaced insn-emit-*.o.
#
# Env: D = build dir (default /tmp/b78).  Read-only.
#
# INSTRUMENT NOTES (PRINCIPLES 4.5 -- state the blind spots):
#   * Names are taken MANGLED and classified by prefix: `_ZN' is namespaced
#     (insn_<base>::), a plain `_Z' is at global scope.  Demangling first and
#     grepping for `::' is WRONG -- `nm -C' prints `gen_foo(rtx_def*)', which
#     contains spaces, so any `sed s/.* //' chops the name mid-way and invents
#     entries like `rtx_def*)'.  That is how this script's first version lied.
#   * Only STRONG defined symbols (T/D/B/R) are counted as definitions.  W
#     (COMDAT) is reported separately: a COMDAT collision is real but has a
#     different mechanism and would otherwise be mixed in silently.
#   * A name defined bare here and referenced bare elsewhere is a COLLISION
#     SURFACE, not proof of a wrong answer: it is only wrong if some other
#     configured base has a pattern of the same name that MEANS something
#     different.  That second question is asked per name, by hand.
set -u -o pipefail
D=${D:-/tmp/b78}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
G=$D/gcc
[ -d "$G" ] || { echo "FATAL: no $G"; exit 9; }

nix-shell -I "nixpkgs=$NP" -p binutils coreutils --substituters 'https://cache.nixos.org/' --run '
set -u -o pipefail
G='"$G"'
command -v nm >/dev/null || { echo "FATAL: no nm"; exit 9; }
cd "$G" || exit 9

set -- insn-emit-*.o
[ -e "$1" ] || { echo "FATAL: no insn-emit-*.o in $G -- nothing to measure"; exit 9; }
echo "primary insn-emit objects: $#"

# 1. Bare (global-scope) strong definitions in the primary insn-emit set.
nm --defined-only insn-emit-*.o \
  | awk "\$2 ~ /^[TDBR]\$/ {print \$3}" \
  | grep "^_Z" | grep -v "^_ZN" | sort -u > /tmp/t51-bare-def.txt
n=$(wc -l < /tmp/t51-bare-def.txt)
echo "bare strong definitions in insn-emit-*.o: $n"
[ "$n" -gt 0 ] || { echo "FATAL: zero -- the instrument found nothing, which is not a result"; exit 9; }

# COMDAT, reported separately rather than folded in.
nm --defined-only insn-emit-*.o | awk "\$2 ~ /^[Ww]\$/ {print \$3}" \
  | grep "^_Z" | grep -v "^_ZN" | sort -u > /tmp/t51-bare-comdat.txt
echo "bare COMDAT (W) definitions in insn-emit-*.o: $(wc -l < /tmp/t51-bare-comdat.txt)"

# 2. Who else in the link REFERENCES those bare names.
#    Everything that goes into libbackend.a plus the middle-end objects.
find . -name "*.o" ! -name "insn-emit-*.o" > /tmp/t51-others.txt
echo "other objects scanned: $(wc -l < /tmp/t51-others.txt)"
: > /tmp/t51-refs.txt
while read -r o; do
  nm -u "$o" 2>/dev/null | awk "{print \$2}" | grep "^_Z" | grep -v "^_ZN" \
    | sort -u | while read -r s; do echo "$s $o"; done
done < /tmp/t51-others.txt >> /tmp/t51-refs.txt

join <(sort /tmp/t51-bare-def.txt) <(sort -k1,1 /tmp/t51-refs.txt) > /tmp/t51-hits.txt
echo "--- bare names DEFINED by the primary insn-emit and REFERENCED elsewhere:"
awk "{print \$1}" /tmp/t51-hits.txt | sort -u > /tmp/t51-hitnames.txt
echo "distinct names: $(wc -l < /tmp/t51-hitnames.txt)"
echo "distinct referencing objects: $(awk "{print \$2}" /tmp/t51-hits.txt | sort -u | wc -l)"
echo
while read -r s; do
  printf "%-40s <- " "$(c++filt "$s")"
  awk -v s="$s" "\$1==s {printf \"%s \", \$2}" /tmp/t51-hits.txt
  echo
done < /tmp/t51-hitnames.txt
'
