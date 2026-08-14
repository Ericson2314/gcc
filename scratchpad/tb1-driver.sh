#!/bin/sh
# THE DRIVER ARM.  tb1-emit.sh drives `cc1' directly, which is why riscv's
# defect was invisible to it: `-march=' reaches cc1 only through the DRIVER,
# from the target spec file's `*option_defaults' and then through riscv's
# `*self_spec' (`%:riscv_expand_arch'), and it is that expansion that ICEd in
# `default_version, at common/config/riscv/riscv-common.cc:162'.  A cc1-only
# harness cannot see it, and cannot see the 32-bit code that came of it.
#
# So this arm runs `xgcc' end to end, and checks THREE things per target:
#   1. the driver survives at all (that is the ICE),
#   2. the target's own cross assembler accepts the output,
#   3. the WORD SIZE is right -- PRINCIPLES records riscv64 passing
#      "assembles, right ELF machine" while emitting `sw' for a `long'.
#
# usage: B=<builddir> TOOLS=<tools dir> sh tb1-driver.sh
set -u
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to a tb1-tools.sh output dir}
case "$B" in
  */b-agent-a7481b*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
[ -f "$B/MY-SRC" ] || { echo "FATAL: $B has no MY-SRC"; exit 9; }
SRC=$(cat "$B/MY-SRC")
VER=$(cat "$SRC/gcc/BASE-VER")
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
echo "== driver arm: $B (srcdir $SRC, gcc $VER)"

W=$B/drv; rm -rf "$W"; mkdir -p "$W"
cat > "$W/t.c" <<'EOF'
long mt_shift (long a, int b) { return (a << b) + (a >> 7); }
/* The semantic witness, and it is DATA rather than an instruction on purpose.
   An instruction arm cannot tell 32-bit code apart on riscv -- `srai' is a
   valid rv32 and rv64 instruction, and PRINCIPLES records exactly that
   confusion.  These two emit the target's own pointer-sized directive with
   the target's own answer in it, so a compiler generating 32-bit code says
   `.word 4' where a correct one says `.dword 8'.  */
unsigned long mt_sizeof_long = sizeof (long);
unsigned long mt_sizeof_ptr  = sizeof (void *);
EOF

# The witness per target: the pointer-sized data directive carrying 8.  Named
# per target rather than derived; a derived "some 8 appeared" arm is the shape
# that passes on the wrong answer.  (A `-'-bearing triple cannot be a shell
# variable name, hence the case.)
witness () {
  case $1 in
    x86_64-*)  printf '.quad\t8' ;;
    aarch64-*) printf '.xword\t8' ;;
    riscv64-*) printf '.dword\t8' ;;
    s390x-*)   printf '.quad\t8' ;;
    *)         printf '' ;;
  esac
}

fail=0
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  C="$B/lib/gcc/$VER/$T/specs-config"
  printf '%-28s ' "$T"
  if [ ! -f "$C" ]; then echo "no specs-config"; fail=1; continue; fi
  if ! "$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$C" -O2 -S \
        -o "$W/$T.s" "$W/t.c" > "$W/$T.out" 2> "$W/$T.err"; then
    echo "DRIVER FAIL: $(grep -m1 'error' "$W/$T.err")"
    fail=1; continue
  fi
  printf 'emit %s bytes  ' "$(wc -c < "$W/$T.s")"

  AS="$TOOLS/bin/$T-as"; RE="$TOOLS/bin/$T-readelf"
  [ -x "$AS" ] || AS=$(command -v as)
  [ -x "$RE" ] || RE=$(command -v readelf)
  if "$AS" -o "$W/$T.o" "$W/$T.s" > "$W/$T.as.out" 2> "$W/$T.as.err"; then
    printf 'AS ok %s/%s  ' \
      "$("$RE" -h "$W/$T.o" | sed -n 's/^ *Class: *//p')" \
      "$("$RE" -h "$W/$T.o" | sed -n 's/^ *Machine: *//p')"
  else
    printf 'AS FAIL(%s)  ' "$(sed -n '1,2p' "$W/$T.as.err" | tr '\n' ' ')"
    fail=1
  fi

  tok=$(witness "$T")
  if [ -n "$tok" ] && grep -qF "$tok" "$W/$T.s"; then
    printf 'sizeof-witness [%s]: PRESENT\n' "$tok"
  else
    printf 'sizeof-witness [%s]: ABSENT -- 32-bit code?\n' "${tok:-none}"
    fail=1
  fi
  # And the arch attribute, which is the artefact riscv got wrong.
  grep -H '\.attribute arch' "$W/$T.s" | head -1 || true
done
echo "== driver arm fail=$fail"
exit $fail
