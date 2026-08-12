#!/usr/bin/env bash
# #104: the shared options.cc `global_options_init' is a POSITIONAL brace
# initializer for `struct gcc_options', whose layout comes from options.h.
# Nothing in the build compares the two, so a member present in one and not the
# other shifts every field after it and lands a value on the wrong type,
# silently.  This is that comparison, made explicit.
#
# Scored as a PREFIX check, which is what optc-gen.awk's own note requires:
# the initializer covers the union's leading run (the primary's members, in
# order) and value-initialises the tail.
#
#   t88-prefix.sh <builddir>/gcc
set -u -o pipefail
D=${1:?usage: t88-prefix.sh <builddir>/gcc}
case $D in /*) ;; *) echo "FATAL: <builddir> must be absolute: $D"; exit 9;; esac
H=$D/options.h; C=$D/options.cc
for f in "$H" "$C"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done

# Struct member order, from the header.  Members are declared either as
# `  TYPE x_NAME;' or, for the GENERATOR_FILE pairs, with a following
# `#define NAME global_options.x_NAME'.  Take the declarations.
# The `SetByCombined' members are `bool frontend_set_<var>;' with NO `x_'
# prefix; a pattern anchored on `x_' drops all 11 of them and the check then
# fails at the first one for a reason that has nothing to do with the build.
sed -n '/^struct gcc_options$/,/^};/p' "$H" \
  | sed -n -e 's/^  .*[ *]x_\([A-Za-z0-9_]*\)\(\[[^]]*\]\)\?;$/\1/p' \
           -e 's/^  bool \(frontend_set_[A-Za-z0-9_]*\);$/\1/p' > /tmp/t88-h.names

# Initializer order, from the .cc.  Every element carries a `/* NAME */' tag --
# EXCEPT the static ones, which are tagged `/* NAME (private state) */'.
# Matching only the first form silently dropped all 209 of them here and the
# check reported a spurious FAIL at the first static member; the interleaved
# `#undef x_NAME' lines must not be counted either.
sed -n '/^struct gcc_options global_options_init =$/,/^};/p' "$C" \
  | sed -n -e 's/^  .*\/\* \([A-Za-z0-9_]*\) \*\/$/\1/p' \
           -e 's/^  .*\/\* \([A-Za-z0-9_]*\) (private state) \*\/$/\1/p' \
           -e 's/^  {}, \/\* \([A-Za-z0-9_]*\) (another back end) \*\/$/\1/p' \
           -e 's/^  {}, \/\* \([A-Za-z0-9_]*\) (private state, another back end) \*\/$/\1/p' \
           -e 's/^  {}, \/\* frontend_set_\([A-Za-z0-9_]*\) (another back end) \*\/$/frontend_set_\1/p' \
  > /tmp/t88-c.names

nh=$(wc -l < /tmp/t88-h.names); nc=$(wc -l < /tmp/t88-c.names)
echo "options.h struct members : $nh"
echo "options.cc initializers  : $nc"
# Neither extraction may be vacuous, and neither may be so small that a prefix
# match is uninformative.  A regex that stops matching scores a silent pass
# otherwise -- that is the failure shape this project keeps paying for.
[ "$nh" -ge 500 ] || { echo "FATAL: only $nh members extracted from $H; the extraction, not the build, is what failed"; exit 9; }
[ "$nc" -ge 500 ] || { echo "FATAL: only $nc initializers extracted from $C"; exit 9; }
[ "$nc" -le "$nh" ] || { echo "FAIL: the initializer has MORE elements ($nc) than the struct has members ($nh); it cannot fit"; exit 1; }

head -n "$nc" /tmp/t88-h.names > /tmp/t88-h.head
if cmp -s /tmp/t88-h.head /tmp/t88-c.names; then
  echo "PASS: the $nc initializers are exactly the first $nc struct members, in order"
  exit 0
fi
echo "FAIL: initializer and struct disagree; first 20 differences:"
diff /tmp/t88-h.head /tmp/t88-c.names | head -20
exit 1
