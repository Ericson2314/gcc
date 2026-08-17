#!/bin/sh
# THE EFFECTIVE-TARGET PROBES ANSWER "NO" FOR A REASON THAT IS NOT THE QUESTION.
#
# `check_effective_target_ilp32' and `check_effective_target_int32plus' are
# `check_no_compiler_messages <name> object { ... }' -- and `object' means the
# ASSEMBLER RUNS.  On the multi-target arm compiler every `.type' directive is
# the primary's `@object', which arm's `as' will not accept, so BOTH probes
# report FALSE while the compiler's own answer about `sizeof (void *)' is
# correct and is never consulted.
#
# There are 189 `object'-mode and 116 `assembly'-mode selectors in
# `target-supports.exp'.  Every one of them is answered by the assembler here.
#
# The `-S' column is the control and it is the whole argument: if the same
# translation unit COMPILES and only fails to ASSEMBLE, then the probe is not
# measuring the property it names.
set -eu
B=${B:?set B to the 47-base build dir}
SB=${SB:?set SB to the stock arm build dir}
T=arm-unknown-linux-gnueabihf
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
CFG="$B/lib/gcc/$VER/$T/specs-config"
AS="$B/asdir-$T"
[ -x "$AS/as" ] || { echo "FATAL: no $AS/as -- GUARD 3c's per-target dir is absent, so this would silently use the HOST assembler"; exit 9; }
W=/tmp/a660907426e03e4e9-et
mkdir -p "$W"
cat > "$W/ilp32.c" <<'EOF'
int dummy[sizeof (int) == 4 && sizeof (void *) == 4 && sizeof (long) == 4 ? 1 : -1];
EOF
cat > "$W/int32plus.c" <<'EOF'
int dummy[sizeof (int) >= 4 ? 1 : -1];
EOF
run () { if "$@" > "$W/e" 2>&1; then echo ok; else echo FAIL; fi; }
printf '%-12s %-10s %-8s %-8s %-8s %s\n' PROBE COMPILER '-S' '-c' 'verdict' 'note'
for p in ilp32 int32plus; do
  for side in mt stock; do
    if [ "$side" = mt ]; then
      set -- "$B/gcc/xgcc" -B"$AS/" -B"$B/gcc/" -ftarget-config="$CFG"
    else
      set -- "$SB/gcc/xgcc" -B"$SB/gcc/"
    fi
    s=$(run "$@" -S -o "$W/$p.s" "$W/$p.c")
    c=$(run "$@" -c -o "$W/$p.o" "$W/$p.c")
    if [ "$s" = ok ] && [ "$c" = FAIL ]; then
      v="FALSE"; note="compiles, will not ASSEMBLE -- the probe measures the assembler"
    elif [ "$c" = ok ]; then v="TRUE"; note=""
    else v="FALSE"; note="does not compile either -- a real negative"
    fi
    printf '%-12s %-10s %-8s %-8s %-8s %s\n' "$p" "$side" "$s" "$c" "$v" "$note"
  done
done
