#!/bin/sh
# agent-ae59966cf819d72ef-jtstride.sh -- THE SEMANTIC ARM.  Does the emitted
# case vector's ENTRY WIDTH match the width the emitted CODE loads?
#
# PRINCIPLES: "assembles, right ELF machine" is not enough -- riscv64 passed
# that bar while emitting 32-bit code.  Both PRE and POST assemble here; the
# question is whether the table the code indexes is the table that was written.
#
#   aarch64  ldr w1, [x1, w0, uxtw #2]      index scaled by 4, loads a WORD
#            add x1, x0, w1, sxtw #2        and the entry is itself SCALED /4
#   riscv    slli a0,a0,2 / lw a5,0(a0)     stride 4, loads a WORD
#
# So the entry must be 4 bytes.  PRE emitted `.quad' -- i386's ASM_QUAD, chosen
# on i386's own unconfigured TARGET_LP64 -- so entry i was read from bytes
# [4i, 4i+4) of an 8-byte-strided table, i.e. the low half of entry i/2.  Every
# jump-table switch reached a wrong address.
#
# The arm is the SIZE OF THE TABLE SECTION, measured from the assembled object
# rather than from the text, plus the directive itself.  A text grep would also
# work and would not survive anyone changing the directive spelling.
set -u
O=${O:-/tmp/w-agent-ae59966cf819d72ef}/jtboth
TOOLS=${TOOLS:?set TOOLS to a dir of real cross binutils}

fail=0; scored=0
for t in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu \
         s390x-ibm-linux-gnu x86_64-pc-linux-gnu ; do
  AS=$TOOLS/bin/$t-as
  RE=$TOOLS/bin/$t-readelf
  [ -x "$AS" ] || { echo "FATAL: no executable $AS -- refusing to fall back to the host as"; exit 9; }
  "$AS" --version > /dev/null 2>&1 || { echo "FATAL: $AS does not RUN"; exit 9; }
  for side in pre post; do
    s=$O/$t.$side.s
    [ -f "$s" ] || { echo "  $t $side: no .s -- run -jtboth.sh first"; fail=$((fail+1)); continue; }
    "$AS" -o "$O/$t.$side.o" "$s" 2> "$O/$t.$side.as.err"
    rc=$?
    if [ $rc -ne 0 ]; then
      printf '%-28s %-4s as rc=%s  %s\n' "$t" "$side" "$rc" "$(head -1 "$O/$t.$side.as.err")"
      fail=$((fail+1)); continue
    fi
    # `readelf -S' prints `[ 1] .text' or `[10] .text', so the bracket is one
    # field or two depending on the section NUMBER.  Stripping the brackets
    # first makes the column position fixed; the version keyed on `$2' read
    # nothing for every object and printed `?', which is a null result wearing
    # a row of output.
    ro=$("$RE" -S -W "$O/$t.$side.o" | tr -d '[]' \
         | awk '$2==".rodata"{printf "%d\n", strtonum("0x" $6)}')
    m=$("$RE" -h "$O/$t.$side.o" | sed -n 's/.*Machine: *//p')
    d=$(grep -oE '^[[:space:]]*\.(quad|word|long|2byte|byte|dword)' "$s" | sort -u | tr -d ' \t' | tr '\n' ' ')
    printf '%-28s %-4s as rc=0  machine=%-28s .rodata=%-4s directives=[%s]\n' \
           "$t" "$side" "$m" "${ro:-?}" "$d"
    scored=$((scored + 1))
  done
done
echo
echo "assembled sides=$scored  failures=$fail"
[ "$scored" -gt 0 ] || { echo "FATAL: nothing assembled -- a null result, not a pass"; exit 9; }
echo
echo "READ THE .rodata COLUMN.  12 entries at 8 bytes is 96; at 4 bytes it is 48."
echo "A target whose code loads a WORD and whose PRE table is 96 bytes was"
echo "indexing a table of twice the stride it believed."
