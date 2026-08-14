#!/bin/sh
# A specs-config for a target with NO CROSS BINUTILS ANYWHERE, so that
# `scan-assembler' coverage is not gated on an assembler it never invokes.
#
# THIS IS THE #113b FALLBACK, ASKED FOR ON PURPOSE.  The config is produced by
# pointing target-specs at the BUILD MACHINE'S OWN `as'/`ld', which is exactly
# the accident PRINCIPLES section 5 warns about: a file NAMING the target while
# DESCRIBING x86_64.  It is used to answer ONE question -- does cc1 reach
# codegen for this back end at all -- and its ANSWERS ARE NOT TRUSTED for
# anything else.  Shape and caveats taken from ta9f-nobinutils.sh (#170).
#
# CONSEQUENCES THAT MUST TRAVEL WITH ANY NUMBER TAKEN THROUGH IT:
#   * ASSEMBLES and ELF-MACHINE stay UNKNOWN.  There is no assembler to be
#     right about, and no output can promote them.
#   * Any test whose verdict depends on an assembler CAPABILITY (.hidden, TLS,
#     CFI, section flags) is reading x86_64's answer under this target's name.
#     Those verdicts are UNTRUSTED, not FAIL and not PASS.
#   * Two such configs may be byte-identical, which is precisely what
#     taa-mtcheck.sh's guard 6 refuses.  Run one target per invocation and say
#     so, rather than relaxing the guard.
set -u
B=${B:?build dir}; T=${1:?target}
S=$(cd "$(dirname "$0")" && pwd)
sh "$S/eb-shell.sh" "
  set -e
  nat=\$(dirname \$(command -v as))
  cd $B && make configure-target-specs-$T TOOLS_DIR_FOR_$T=\$nat \
    TARGET_SPECS_FLAGS_FOR_$T=\"--with-as=\$nat/as --with-ld=\$nat/ld \
      --with-nm=\$nat/nm --with-objdump=\$nat/objdump \
      --with-readelf=\$nat/readelf\"
" > "$B/fbspecs-$T.out" 2> "$B/fbspecs-$T.err"
echo "rc=$?"
F=$(ls "$B"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
if [ -n "$F" ]; then
  printf '%-24s FALLBACK specs-config  wc -l %s  md5 %s\n' "$T" \
    "$(wc -l < "$F")" "$(md5sum < "$F" | cut -c1-12)"
else
  echo "$T: no specs-config even with the fallback:"
  grep -m3 -i 'error' "$B/fbspecs-$T.err" | cut -c1-120
fi
