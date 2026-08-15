#!/bin/sh
# #208 -- read the PREDICATE, not the symptom.
#
# `targetm_common->except_unwind_info (&global_options)' is the single value
# that both symptoms hang off:
#
#   dwarf2cfi.cc:3723 dwarf2out_do_eh_frame  == UI_DWARF2  -> emit CFI
#   opts.cc:1564      diagnose_options       == UI_SJLJ    -> kill
#                                                -freorder-blocks-and-partition
#
# Two observables that report it WITHOUT compiling a function, so neither can
# be confused with a codegen failure:
#
#   ARM 1  __USING_SJLJ_EXCEPTIONS__  (c-family/c-cppbuiltin.cc:1221) is
#          predefined if and only if the hook says UI_SJLJ.  A preprocessor
#          macro is present or absent -- no empty-vs-missing ambiguity.
#   ARM 2  the `-freorder-blocks-and-partition does not work with exceptions
#          on this architecture' note, which opts.cc emits only on the SJLJ
#          branch and only when the flag was set EXPLICITLY.
#
# Both arms must be able to report both ways on the same run, so x86_64 is
# carried beside aarch64 as the live positive control: x86_64 supplies its own
# TARGET_EXCEPT_UNWIND_INFO (i386-common.cc:2133) and must show UI_DWARF2.
set -eu
B=${1:?build dir}
SRC=${SRC:?set SRC}
V=$(cat "$SRC/gcc/BASE-VER")
shift
[ -x "$B/gcc/cc1" ] || { echo "FATAL: no cc1 in $B"; exit 9; }

E=/tmp/uwarm-empty.c
: > "$E"

for t in "$@"; do
  cfg=$B/lib/gcc/$V/$t/specs-config
  [ -s "$cfg" ] || { echo "$t: FATAL no $cfg"; exit 9; }

  # ARM 1 -- ask cpp for its predefined macros.
  ( cd "$B/gcc" && ./cc1 -quiet -nostdinc -E -dM -fexceptions \
      -ftarget-config="$cfg" "$E" ) > /tmp/uwarm-$t.dM 2> /tmp/uwarm-$t.dMerr || true
  # Non-vacuity: -dM must have produced a real macro list, or "no SJLJ macro"
  # is just "no output".
  nm=$(grep -c '^#define ' /tmp/uwarm-$t.dM || true)
  sjlj=$(grep -c '^#define __USING_SJLJ_EXCEPTIONS__' /tmp/uwarm-$t.dM || true)

  # ARM 2 -- the opts.cc note.
  ( cd "$B/gcc" && ./cc1 -quiet -nostdinc -O2 -fexceptions \
      -freorder-blocks-and-partition -ftarget-config="$cfg" \
      "$SRC/scratchpad/agent-a62563d5673423af6-cfi.c" -o /tmp/uwarm-$t.s ) \
      > /tmp/uwarm-$t.out 2> /tmp/uwarm-$t.err || true
  note=$(grep -c 'reorder-blocks-and-partition' /tmp/uwarm-$t.err || true)

  case "$nm" in 0) echo "$t: FATAL -dM produced no macros at all; arm 1 proved nothing"; exit 9 ;; esac
  if [ "$sjlj" = 0 ]; then ui=DWARF2; else ui=SJLJ; fi
  printf '%-28s hook=%-6s  __USING_SJLJ_EXCEPTIONS__=%s  rbp-note=%s  (%s predefines)\n' \
    "$t" "$ui" "$sjlj" "$note" "$nm"
done
