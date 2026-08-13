#!/bin/sh
# Identical to eb-reconf.sh except it uses the OLD flag spelling, so that the
# ONLY difference between /tmp/b-eb and /tmp/b-eb-ctl is the rename itself.
#
# CONF-AUDIT-EXEMPT: TARGETS-ON-GCC-CONFIGURE -- passing --enable-targets to
# gcc/configure IS THE POINT of this file.  gcc/'s --enable-targets was renamed
# --enable-backends; this arm spells the OLD name so that the A/B against
# eb-reconf.sh isolates the rename.  "Repairing" it would delete the control.
#
# BUT NOTE A REAL WEAKNESS, FOUND WHILE AUDITING AND NOT FIXED HERE: this
# script passes --disable-option-checking (below), under which an unrecognised
# --enable-targets is SILENTLY IGNORED rather than refused.  So this control
# arm cannot currently distinguish "the old name is gone" from "the old name
# was accepted and did nothing" -- both produce a tree configured with neither
# flag.  That is the absent-artefact/absent-mechanism confusion in miniature.
# Recorded rather than changed: this pair is historical evidence for a rename
# that has since been re-established by other means (gcc/configure.ac contains
# zero occurrences of `enable-targets', measured), and rewriting it now would
# edit the record rather than the code.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/../gcc" && pwd)
# REFUSE THE WRONG TREE.  This line used to name ANOTHER agent's
# worktree; those trees measure 27-28 `MULTI_TARGET' hits in
# gcc/Makefile.in against this one's 39, so the script configured and
# built a STALE compiler and reported a clean green for it, with no
# diagnostic.  0 hits is the documented bare-repo-HEAD case
# (PRINCIPLES section 5).
grep -q MULTI_TARGET "$SRC/gcc/Makefile.in" || { echo "FATAL: $SRC is not a multi-target tree"; exit 9; }
cd /tmp/b-eb-ctl/gcc
"$SRC/configure" \
  --srcdir="$SRC" \
  --disable-werror \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  --enable-languages=c,lto \
  --program-transform-name=s,y,y, \
  --disable-option-checking \
  --disable-year2038 \
  --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu --target=x86_64-pc-linux-gnu \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security  ' \
  LDFLAGS='-static-libstdc++ -static-libgcc ' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security  ' \
  GMPLIBS='-lmpc -lmpfr -lgmp' GMPINC= ISLLIBS= ISLINC=
