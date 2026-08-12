#!/bin/sh
# ARM 1 -- a NON-PRIMARY back end's members round-tripping through the
# generated save/restore/eq/hash/compare code, plus a NEGATIVE CONTROL built
# from the primary's optionlist alone.
#
# Links cc1's own object set with main.o replaced.  See t77main.cc for why
# this is a harness and not a cc1 invocation (aarch64 selection ICEs in
# init_reg_sets_1 on this branch, pre-existing, reproduces on /tmp/b-objs).
set -u
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-af7e06a12bc211827
B=/tmp/b-77t/gcc
cd $B || exit 9
rc=0

INC="-I. -I$W/gcc -I$W/gcc/. -I$W/gcc/../include -I$W/gcc/../libcpp/include -I$W/gcc/../libcody -I$W/gcc/../libdecnumber -I$W/gcc/../libdecnumber/bid -I../libdecnumber -I$W/gcc/../libbacktrace"
CFLAGS="-fno-PIE -g0 -Wno-error=format-security -DIN_GCC -fno-exceptions -fno-rtti -DHAVE_CONFIG_H -DMULTI_TARGET_OPTION_TABLES"

link () {   # link <exe> <options-save object>
  g++ -no-pie -g0 -Wno-error=format-security -DIN_GCC -fno-exceptions -fno-rtti \
    -fasynchronous-unwind-tables -no-pie -static-libstdc++ -static-libgcc -o "$1" \
    c/c-lang.o c-family/stub-objc.o attribs.o c/c-errors.o c/c-decl.o c/c-typeck.o \
    c/c-convert.o c/c-aux-info.o c/c-objc-common.o c/c-parser.o c/c-fold.o \
    c/gimple-parser.o c-family/c-common.o c-family/c-cppbuiltin.o c-family/c-dump.o \
    c-family/c-format.o c-family/c-gimplify.o c-family/c-indentation.o c-family/c-lex.o \
    c-family/c-omp.o c-family/c-opts.o c-family/c-pch.o c-family/c-ppoutput.o \
    c-family/c-pragma.o c-family/c-pretty-print.o c-family/c-semantics.o \
    c-family/c-ada-spec.o c-family/c-ubsan.o c-family/known-headers.o c-family/c-attribs.o \
    c-family/c-warn.o c-family/c-spellcheck.o c-family/c-type-mismatch.o i386-c.o glibc-c.o \
    cc1-checksum.o simple-diagnostic-path.o diagnostics/lazy-paths.o \
    "$2" t77main.o libbackend.a \
    libcommon-target.a libcommon.a ../libcpp/libcpp.a ../libdecnumber/libdecnumber.a \
    libcommon.a ../libcpp/libcpp.a ../libbacktrace/.libs/libbacktrace.a \
    ../libiberty/libiberty.a ../libdecnumber/libdecnumber.a \
    -lmpc -lmpfr -lgmp -rdynamic -L./../zlib -lz
}

g++ -c $CFLAGS $INC -o t77main.o $W/scratchpad/t77main.cc \
  || { echo "FATAL: harness compile failed"; exit 9; }

# The NEGATIVE CONTROL: options-save.cc generated WITHOUT the union list, i.e.
# from the primary (i386) optionlist alone -- what this file was before
# 52fa9e763c5.  It is compiled against the same, UNIONED options.h, so it is
# exactly the defect: members laid out, never walked.
awk -f $W/gcc/opt-functions.awk -f $W/gcc/opt-read.awk \
    -f $W/gcc/optc-save-gen.awk \
    -v header_name="config.h system.h coretypes.h tm.h" \
    < optionlist > t77-options-save-primaryonly.cc 2> t77-negctl-gen.err \
  || { echo "FATAL: could not generate the primary-only control"; cat t77-negctl-gen.err; exit 9; }
[ -s t77-options-save-primaryonly.cc ] || { echo "FATAL: control generated nothing"; exit 9; }
if cmp -s t77-options-save-primaryonly.cc options-save.cc; then
  echo "FATAL: the control is byte-identical to the real options-save.cc --"
  echo "       the union list is not affecting the build and nothing is under test"
  exit 9
fi
echo "control: primary-only options-save.cc is $(wc -l < t77-options-save-primaryonly.cc) lines vs $(wc -l < options-save.cc) unioned"
echo "control: aarch64 mentions -- primary-only $(grep -c aarch64 t77-options-save-primaryonly.cc), unioned $(grep -c aarch64 options-save.cc)"

g++ -c $CFLAGS $INC -o t77-options-save-primaryonly.o t77-options-save-primaryonly.cc \
  || { echo "FATAL: control did not compile"; exit 9; }

link t77harness         options-save.o                   || { echo "FATAL: link failed"; exit 9; }
link t77harness-negctl  t77-options-save-primaryonly.o   || { echo "FATAL: control link failed"; exit 9; }

echo
echo "================ UNIONED (the build under test) ================"
./t77harness; u=$?
echo "unioned harness rc=$u"
[ $u -eq 0 ] || rc=1

echo
echo "================ NEGATIVE CONTROL (primary's list alone) ================"
./t77harness-negctl > t77-negctl.out 2>&1; n=$?
sed 's/^/  /' t77-negctl.out
echo "control harness rc=$n"
if [ $n -eq 0 ]; then
  echo "  FATAL: the primary-only build PASSED the round trip -- then the union"
  echo "         list is not what makes it work and this arm proves nothing"
  rc=1
else
  echo "  ok: the primary-only build FAILS ($(grep -c '  FAIL' t77-negctl.out) checks), which is the defect"
fi

echo
echo "================ cl_optimization_compare ================"
for exe in t77harness t77harness-negctl; do
  ./$exe compare-same   > $exe-same.out 2>&1;   s=$?
  ./$exe compare-differ > $exe-differ.out 2>&1; d=$?
  echo "$exe: same rc=$s  differ rc=$d"
done
echo "expected: t77harness same=0 differ!=0 (the aarch64 member is compared)"
echo "          t77harness-negctl same=0 differ=0 (it is not)"
if [ "$(./t77harness compare-same >/dev/null 2>&1; echo $?)" != 0 ]; then
  echo "  FAIL: identical copies compared unequal"; rc=1
fi
if ./t77harness compare-differ > /dev/null 2>&1; then
  echo "  FAIL: cl_optimization_compare ignored the aarch64-only member"; rc=1
else
  echo "  ok: cl_optimization_compare reports the aarch64-only member"
fi
if ./t77harness-negctl compare-differ > /dev/null 2>&1; then
  echo "  ok (control): the primary-only compare ignores it, as the defect predicts"
else
  echo "  FATAL: the control also reported it -- the C-record change is not what"
  echo "         makes the difference and this arm proves nothing"
  rc=1
fi

echo
echo "HARNESS OVERALL rc=$rc"
exit $rc
