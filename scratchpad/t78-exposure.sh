#!/bin/sh
# #78, the OTHER half of the brief: "check whether lto-wrapper, collect2 and
# the LTO paths have the same exposure -- a spec a user can replace is not a
# carrier."
#
# cc1 was taken off spec text by 4c3494e210c because `-specs=' can replace
# `*cpp_options'/`*cc1_options' and a copied-and-edited stock file has no
# %(cc1_target_config) in it.  collect2 still gets its copy from
# %(link_target_config) inside LINK_COMMAND_SPEC.  This measures whether that
# is replaceable in the same way, by doing the replacing.
#
# The spec file below is the minimal form of the pr48524.c shape: a user file
# that names a spec and supplies a different (here empty) value.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b78}
T=${T:-x86_64-pc-linux-gnu}
WORK=${WORK:-/tmp/t78}
SHIM=$WORK/shim
G=$D/gcc
DRV=./$T-gcc
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
export T78_REAL="$G/lto-wrapper"

[ -x "$G/$T-gcc" ] || { echo "FATAL: no driver"; exit 9; }
[ -s "$WORK/a.o" ] || { echo "FATAL: no LTO object; run t78-run.sh first"; exit 9; }

# The body must be NON-EMPTY text or read_specs rejects the file ("specs file
# malformed after 22 characters") -- measured.  `%{fzzz:...}' is a conditional
# on an option nobody passes, so it is text that expands to nothing: exactly
# the "user replaced this spec and their value does not mention the target"
# case, without relying on an empty line the parser will not take.
printf '*link_target_config:\n%%{fzzz:-ftarget-config=/nowhere}\n\n' > "$WORK/blank.specs"
[ -s "$WORK/blank.specs" ] || { echo "FATAL: spec file not written"; exit 9; }

run_shell () {
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl binutils coreutils \
    --substituters 'https://cache.nixos.org/' --run "$1"
}

n () { c=$(grep -c "$2" "$1" || true); echo "${c:-0}"; }

echo "=== BASELINE (no -specs=)"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -### -nostdlib -nostartfiles -flto $WORK/a.o $WORK/b.o -o $WORK/x1.exe" \
  > "$WORK/X1.txt" 2>&1
echo "  collect2 argv carries -ftarget-config=<path>: $(n "$WORK/X1.txt" 'collect2.*-ftarget-config=/')"

echo
echo "=== WITH a user -specs= that replaces *link_target_config with nothing"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -specs=$WORK/blank.specs -### -nostdlib -nostartfiles -flto $WORK/a.o $WORK/b.o -o $WORK/x2.exe" \
  > "$WORK/X2.txt" 2>&1
echo "  collect2 argv carries -ftarget-config=<path>: $(n "$WORK/X2.txt" 'collect2.*-ftarget-config=/')"
# NOT a statement about cc1: this command line has only .o inputs, so no cc1
# runs on it at all.  It is here to show that the ONLY occurrence in the
# baseline was the collect2 one, so the 1 -> 0 above is the whole effect.
echo "  any -ftarget-config=<path> anywhere on the -### output: $(n "$WORK/X2.txt" -- '-ftarget-config=/')"

echo
echo "=== and does the LTO route still work with that spec file?"
export T78_LOG="$WORK/wrap-X.log" T78_TAG=X
rm -f "$WORK/wrap-X.log"
run_shell "cd $G && $DRV -B$SHIM/ -B./ -specs=$WORK/blank.specs -nostdlib -nostartfiles -flto $WORK/a.o $WORK/b.o -o $WORK/x2.exe" \
  > "$WORK/X2run.txt" 2>&1
echo "  link rc=$?  x2.exe=$(test -s $WORK/x2.exe && echo yes || echo NO)"
if [ -s "$WORK/wrap-X.log" ]; then
  grep -E '^--- (argv|env) +has' "$WORK/wrap-X.log" | sed 's/^/    /'
else
  echo "    lto-wrapper was not invoked"
fi
tail -3 "$WORK/X2run.txt" | sed 's/^/    /'
