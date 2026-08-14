#!/bin/sh
# #163 -- every READ of `targetm.have_tls' becomes `target_have_tls_p ()'.
#
# THE READS AND THE WRITES ARE NOT THE SAME SITE, AND A BLIND SED WOULD HAVE
# EATEN BOTH.  Two places ASSIGN to the hook -- config/vxworks.cc:136
# (`targetm.have_tls = VXWORKS_HAVE_TLS') and config/xtensa/xtensa.cc:2991
# (`targetm.have_tls = false') -- and both are a back end refining its OWN
# static answer at startup, which is exactly the half that must keep going
# through the hook.  Rewriting them would produce `target_have_tls_p () =
# false', i.e. a compile error, so this one fails loudly; the point of naming
# it is that the NEXT such field might not.
#
# Why every read has to move rather than only the interesting ones: for the
# fourteen back ends whose hook USED to be the probe, a bare `targetm.have_tls'
# now reads `true' unconditionally.  A site left behind has silently stopped
# consulting the assembler, with no diagnostic.
set -e
cd "$(dirname "$0")/../gcc"

# Files with reads.  target.h holds the accessor itself and is excluded by
# name; the two assigning files are excluded by the guard below.
FILES="builtins.def c-family/c-attribs.cc d/d-attribs.cc d/d-builtins.cc \
dwarf2out.cc rtlanal.cc tree-emutls.cc tree-profile.cc varasm.cc varpool.cc \
config/i386/i386.md config/i386/sol2.h config/sparc/sol2.h \
config/nds32/nds32-md-auxiliary.cc config/xtensa/xtensa.cc"

before=0
after=0
for f in $FILES; do
  [ -f "$f" ] || { echo "FATAL: $f absent"; exit 9; }
  b=$(grep -c 'targetm\.have_tls' "$f" || true)
  before=$((before + b))
  # An ASSIGNMENT would become a compile error; refuse instead of writing one.
  if grep -q 'targetm\.have_tls[ \t]*=[^=]' "$f"; then
    # xtensa.cc has both; rewrite only the reads, and assert the assignment
    # survives untouched.
    sed -i 's/targetm\.have_tls\([ \t]*\)\([^ \t=]\)/target_have_tls_p ()\1\2/g; s/targetm\.have_tls)/target_have_tls_p ())/g; s/targetm\.have_tls$/target_have_tls_p ()/g' "$f"
    grep -q 'targetm\.have_tls[ \t]*=[^=]' "$f" \
      || { echo "FATAL: $f lost its assignment to the hook"; exit 9; }
  else
    sed -i 's/targetm\.have_tls/target_have_tls_p ()/g' "$f"
  fi
  a=$(grep -c 'targetm\.have_tls' "$f" || true)
  after=$((after + a))
  printf '%-38s %s -> %s\n' "$f" "$b" "$a"
done

echo "targetm.have_tls occurrences in these files: $before -> $after"
[ "$before" -ge 20 ] || { echo "FATAL: only $before read sites found; the census did not read"; exit 9; }
# The only survivors permitted are the two assignments, both in xtensa.cc.
[ "$after" = 1 ] || { echo "FATAL: $after occurrences left, expected 1 (xtensa's assignment)"; exit 9; }
echo "vxworks.cc and xtensa.cc assignments left alone:"
grep -n 'targetm\.have_tls' config/vxworks.cc config/xtensa/xtensa.cc || true
