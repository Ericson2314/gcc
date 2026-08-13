#!/bin/sh
# TASK #113 -- the $(eval) probe mandated by TOPLEVEL-DESIGN.md section 8 item 1
# / section 7(3): the load-bearing unmeasured claim of the whole top-level
# restructure.
#
# QUESTION: can ONE target module (libgcc) have its real, unmodified recipe
# text expressed as a make `define' block, expanded across N=2 targets with
# $(foreach)/$(eval), and produce a COMPLETE, NON-EMPTY, CORRECT rule set for
# each target?
#
# METHOD.  Two makefiles are built and compared:
#
#   probe-lit.mk   the CONTROL.  The real recipe text, lifted verbatim out of
#                  the shipped generated Makefile.in, written out ONCE PER
#                  TARGET literally (design doc option (B)).  Its quoting is
#                  the shipped quoting -- this file does not go through
#                  $(eval) and cannot be wrong in the way the probe might be.
#   probe-eval.mk  the SUBJECT.  One `define' block, expanded by
#                  $(foreach)/$(eval) (design doc option (C), the make half of
#                  the accepted split-loop route).
#
# The verdict is `make -n' (dry run: nothing is executed, only the fully
# expanded recipe is printed) of the SAME goal in each, diffed byte for byte,
# FOR EVERY TARGET.  Byte-identical for all N is the pass.
#
# WHY -n AND NOT A REAL BUILD.  The question this probe answers is whether the
# EXPANSION is right, and -n prints exactly the text make would hand the
# shell.  A real build would additionally require two cross toolchains and
# would confound "expansion is wrong" with "the cross compiler is missing" --
# the DEVSHELL failure this project already records.  Stated as a blind spot
# below rather than left implicit.
#
# BLIND SPOTS, stated per PRINCIPLES 4 rule 5:
#   * -n does not execute, so a recipe that expands correctly and then fails at
#     run time is scored PASS here.  This probe is about expansion only.
#   * Only the non-bootstrap `configure' and `all' rules are covered.  The
#     bootstrap stage machinery (Makefile.tpl:1779-1793) is the design doc's
#     own stated worst case and is NOT probed here.  Do not read a pass here
#     as a verdict on bootstrap staging.
#   * One module, not 26.  The claim tested is "the quoting is tractable",
#     which the design doc says generalises; that generalisation is not itself
#     measured.
set -u

S=$(cd "$(dirname "$0")" && pwd)
W=${W:-/tmp/t113-eval}
SHELLSH="$S/eb-shell.sh"

T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu

rm -rf "$W"
mkdir -p "$W" || exit 9

# ---------------------------------------------------------------- non-vacuity
# PRINCIPLES 7: a harness must refuse to score when it cannot show it read
# anything.  Assert the tools exist and the source text was actually found
# BEFORE any comparison, so an all-empty read can never read as agreement.
[ -f "$SHELLSH" ] || { echo "FATAL: no $SHELLSH"; exit 9; }
sh "$SHELLSH" 'command -v make' > "$W/make.path" 2> "$W/make.err" || {
  echo "FATAL: no make in the dev shell"; cat "$W/make.err"; exit 9; }
[ -s "$W/make.path" ] || { echo "FATAL: make.path empty"; exit 9; }

# ------------------------------------------------- the shared preamble/stubs
# Variables the real recipes reference.  Values are marked so that if any one
# of them silently expanded to empty, the diff and the marker check below both
# notice.  NOTHING here may be empty: an empty expansion is the exact
# fail-silent shape this probe exists to detect.
cat > "$W/stub.mk" <<'STUBEOF'
PWD_COMMAND = MARK_PWD
srcdir = MARK_SRCDIR
SHELL = /bin/sh
CC_FOR_TARGET = MARK_CC_FOR_TARGET
NORMAL_TARGET_EXPORTS = MARK_EXPORTS;
TARGET_CONFIGARGS = MARK_CONFIGARGS
BASE_FLAGS_TO_PASS = MARK_BASEFLAGS
EXTRA_TARGET_FLAGS = MARK_EXTRAFLAGS
MAKE = MARK_MAKE
build_alias = MARK_BUILD
STUBEOF

# =========================================================== CONTROL: literal
# Written out once per target, by literal substitution of the target for
# $(TARGET_SUBDIR) in the shipped text.  This is NOT generated from the define
# block, so it is independent evidence.
gen_literal () {
  t=$1
  cat <<LITEOF
.PHONY: configure-target-libgcc-$t
configure-target-libgcc-$t:
	@r=\`\${PWD_COMMAND}\`; export r; \\
	s=\`cd \$(srcdir); \${PWD_COMMAND}\`; export s; \\
	echo "Checking multilib configuration for libgcc..."; \\
	\$(SHELL) \$(srcdir)/mkinstalldirs $t/libgcc; \\
	\$(CC_FOR_TARGET) --print-multi-lib > $t/libgcc/multilib.tmp 2> /dev/null; \\
	if test -r $t/libgcc/multilib.out; then \\
	  if cmp -s $t/libgcc/multilib.tmp $t/libgcc/multilib.out; then \\
	    rm -f $t/libgcc/multilib.tmp; \\
	  else \\
	    rm -f $t/libgcc/Makefile; \\
	    mv $t/libgcc/multilib.tmp $t/libgcc/multilib.out; \\
	  fi; \\
	else \\
	  mv $t/libgcc/multilib.tmp $t/libgcc/multilib.out; \\
	fi; \\
	test ! -f $t/libgcc/Makefile || exit 0; \\
	\$(SHELL) \$(srcdir)/mkinstalldirs $t/libgcc; \\
	\$(NORMAL_TARGET_EXPORTS)  \\
	echo Configuring in $t/libgcc; \\
	cd "$t/libgcc" || exit 1; \\
	case \$(srcdir) in \\
	  /* | [A-Za-z]:[\\\\/]*) topdir=\$(srcdir) ;; \\
	  *) topdir=\`echo $t/libgcc/ | \\
		sed -e 's,\\./,,g' -e 's,[^/]*/,../,g' \`\$(srcdir) ;; \\
	esac; \\
	module_srcdir=libgcc; \\
	rm -f no-such-file || : ; \\
	CONFIG_SITE=no-such-file \$(SHELL) \\
	  \$\$s/\$\$module_srcdir/configure \\
	  \$(TARGET_CONFIGARGS) --build=\${build_alias} --host=$t \\
	  || exit 1

.PHONY: all-target-libgcc-$t
TARGET-target-libgcc-$t=all
all-target-libgcc-$t: configure-target-libgcc-$t
	@r=\`\${PWD_COMMAND}\`; export r; \\
	s=\`cd \$(srcdir); \${PWD_COMMAND}\`; export s; \\
	\$(NORMAL_TARGET_EXPORTS)  \\
	(cd $t/libgcc && \\
	  \$(MAKE) \$(BASE_FLAGS_TO_PASS) \$(EXTRA_TARGET_FLAGS)   \\
		\$(TARGET-target-libgcc-$t))
LITEOF
}

{
  echo "include $W/stub.mk"
  gen_literal "$T1"
  gen_literal "$T2"
} > "$W/probe-lit.mk"

# ============================================================= SUBJECT: $(eval)
# ONE parameterised block, expanded across the target list by make.
#
# THE QUOTING RULE, which is the entire risk the design doc names:
# `$(eval $(call blk,T))' expands the body TWICE -- once by `call' (which
# substitutes $(1)), then `eval' parses the result as makefile text.  So every
# `$' that must survive to RULE time is written `$$' here, and every `$' that
# must survive to the SHELL is written `$$$$'.  Getting this wrong yields a
# silently empty or silently wrong recipe, not an error -- hence the control.
cat > "$W/probe-eval.mk" <<EVALEOF
include $W/stub.mk

MT_TARGETS = $T1 $T2

# FAIL BY NAME if the list is empty.  Without this a zero-length list expands
# to zero rules and the build succeeds having built nothing -- the false green
# PRINCIPLES 6 requires a negative control for.
ifeq (\$(strip \$(MT_TARGETS)),)
\$(error MT_TARGETS is empty: no target was configured, so no target-module rules exist)
endif

define libgcc_target_rules
.PHONY: configure-target-libgcc-\$(1)
configure-target-libgcc-\$(1):
	@r=\`\$\${PWD_COMMAND}\`; export r; \\
	s=\`cd \$\$(srcdir); \$\${PWD_COMMAND}\`; export s; \\
	echo "Checking multilib configuration for libgcc..."; \\
	\$\$(SHELL) \$\$(srcdir)/mkinstalldirs \$(1)/libgcc; \\
	\$\$(CC_FOR_TARGET) --print-multi-lib > \$(1)/libgcc/multilib.tmp 2> /dev/null; \\
	if test -r \$(1)/libgcc/multilib.out; then \\
	  if cmp -s \$(1)/libgcc/multilib.tmp \$(1)/libgcc/multilib.out; then \\
	    rm -f \$(1)/libgcc/multilib.tmp; \\
	  else \\
	    rm -f \$(1)/libgcc/Makefile; \\
	    mv \$(1)/libgcc/multilib.tmp \$(1)/libgcc/multilib.out; \\
	  fi; \\
	else \\
	  mv \$(1)/libgcc/multilib.tmp \$(1)/libgcc/multilib.out; \\
	fi; \\
	test ! -f \$(1)/libgcc/Makefile || exit 0; \\
	\$\$(SHELL) \$\$(srcdir)/mkinstalldirs \$(1)/libgcc; \\
	\$\$(NORMAL_TARGET_EXPORTS)  \\
	echo Configuring in \$(1)/libgcc; \\
	cd "\$(1)/libgcc" || exit 1; \\
	case \$\$(srcdir) in \\
	  /* | [A-Za-z]:[\\\\/]*) topdir=\$\$(srcdir) ;; \\
	  *) topdir=\`echo \$(1)/libgcc/ | \\
		sed -e 's,\\./,,g' -e 's,[^/]*/,../,g' \`\$\$(srcdir) ;; \\
	esac; \\
	module_srcdir=libgcc; \\
	rm -f no-such-file || : ; \\
	CONFIG_SITE=no-such-file \$\$(SHELL) \\
	  \$\$\$\$s/\$\$\$\$module_srcdir/configure \\
	  \$\$(TARGET_CONFIGARGS) --build=\$\${build_alias} --host=\$(1) \\
	  || exit 1

.PHONY: all-target-libgcc-\$(1)
TARGET-target-libgcc-\$(1)=all
all-target-libgcc-\$(1): configure-target-libgcc-\$(1)
	@r=\`\$\${PWD_COMMAND}\`; export r; \\
	s=\`cd \$\$(srcdir); \$\${PWD_COMMAND}\`; export s; \\
	\$\$(NORMAL_TARGET_EXPORTS)  \\
	(cd \$(1)/libgcc && \\
	  \$\$(MAKE) \$\$(BASE_FLAGS_TO_PASS) \$\$(EXTRA_TARGET_FLAGS)   \\
		\$\$(TARGET-target-libgcc-\$(1)))
endef

\$(foreach t,\$(MT_TARGETS),\$(eval \$(call libgcc_target_rules,\$(t))))
EVALEOF


# A harmless goal so `make -p' can dump the rule database without building
# anything real.
for f in probe-lit probe-eval; do
  printf 'mtprobe_noop:\n\t@:\n' >> "$W/$f.mk"
done

# ====================================================================== RUN
#
# TWO instruments, because each has a blind spot the other covers:
#
#  (p) `make -p' dumps the STORED recipe text of every rule.  This is what
#      $(eval) actually installed, and comparing it against the literal
#      control is the direct test of the quoting.  It covers BOTH rules,
#      including the `all' rule.
#  (n) `make -n' prints the FULLY EXPANDED text make would hand the shell.
#      Stronger, but usable only on `configure-target-libgcc-*': the `all'
#      rule contains $(MAKE), and GNU make deliberately EXECUTES recipe lines
#      containing $(MAKE) even under --dry-run.  MEASURED HERE: the first
#      version of this probe used -n on the `all' rule and the recipe RAN
#      (`MARK_PWD: command not found'), which is a real documented property of
#      make, not a bug in the stubs.
#
# Neither instrument alone would be trusted: (p) covers both rules but
# compares stored text, (n) confirms that identical stored text does in fact
# expand identically.

extract_rule () {   # $1 = -p output file, $2 = goal
  awk -v goal="$2" '
    index($0, goal ":") == 1 { inb = 1; print; next }
    inb && /^#/  { next }
    inb && /^$/  { inb = 0; next }
    inb          { print }
  ' "$1"
}

for k in lit eval; do
  sh "$SHELLSH" "cd $W && make -p -f probe-$k.mk mtprobe_noop" \
    > "$W/p.$k" 2> "$W/perr.$k"
  [ -s "$W/p.$k" ] || { echo "FATAL: -p output empty for $k"; cat "$W/perr.$k"; exit 9; }
done

for t in "$T1" "$T2"; do
  for k in lit eval; do
    extract_rule "$W/p.$k" "configure-target-libgcc-$t" > "$W/rule.cfg.$k.$t"
    extract_rule "$W/p.$k" "all-target-libgcc-$t"       > "$W/rule.all.$k.$t"
    sh "$SHELLSH" "cd $W && make -n -f probe-$k.mk configure-target-libgcc-$t" \
      > "$W/exp.$k.$t" 2> "$W/experr.$k.$t"
  done
done

# ------------------------------------------------------------- normalisation
# MEASURED: $(call)/$(eval) COLLAPSES backslash-newline continuations, while
# the literal form keeps them.  make hands the recipe to /bin/sh with the
# continuations intact and sh joins them, so the two forms are the SAME
# command and differ only in physical layout.  Normalise both sides
# identically to the text the shell receives.  Arm 4 proves this has not
# flattened the comparison into insensitivity.
for t in "$T1" "$T2"; do
  for k in lit eval; do
    for r in cfg all; do
      sh "$S/t113-norm.sh" "$W/rule.$r.$k.$t" > "$W/n.$r.$k.$t"
    done
    sh "$S/t113-norm.sh" "$W/exp.$k.$t" > "$W/n.exp.$k.$t"
  done
done

echo "=============================================================="
echo "NON-VACUITY: every extracted rule must be non-empty and complete"
echo "=============================================================="
vac=0
for t in "$T1" "$T2"; do
  for k in lit eval; do
    for r in cfg all; do
      f="$W/n.$r.$k.$t"; n=$(wc -c < "$f")
      printf '  %-4s %-5s %-28s bytes=%-6s' "$r" "$k" "$t" "$n"
      # A silently-empty recipe -- the failure mode this probe exists to find
      # -- lands here as a tiny byte count, NOT as an error.
      [ "$n" -ge 200 ] || { printf ' TOO-SHORT'; vac=1; }
      grep -q -- "$t/libgcc" "$f" || { printf ' NO-TARGETDIR'; vac=1; }
      printf '\n'
    done
    f="$W/n.exp.$k.$t"; n=$(wc -c < "$f")
    printf '  %-4s %-5s %-28s bytes=%-6s' "exp" "$k" "$t" "$n"
    [ "$n" -ge 200 ] || { printf ' TOO-SHORT'; vac=1; }
    # the EXPANDED arm must show the stubs actually substituted
    grep -q MARK_SRCDIR "$f" || { printf ' STUB-NOT-EXPANDED'; vac=1; }
    if grep -q -- '\$(' "$f"; then printf ' LEFTOVER-DOLLARPAREN'; vac=1; fi
    printf '\n'
  done
done
[ $vac -eq 0 ] || { echo "FATAL: non-vacuity failed; comparisons would be meaningless"; exit 9; }

echo
echo "=============================================================="
echo "ARM 1 (AFFIRMATIVE): eval rules == literal rules, PER TARGET"
echo "=============================================================="
arm1=0
for t in "$T1" "$T2"; do
  for r in cfg all; do
    if cmp -s "$W/n.$r.lit.$t" "$W/n.$r.eval.$t"; then
      echo "  IDENTICAL  stored $r  $t  (md5 $(md5sum < "$W/n.$r.eval.$t" | cut -c1-12))"
    else
      echo "  DIFFERS    stored $r  $t"
      diff "$W/n.$r.lit.$t" "$W/n.$r.eval.$t" | head -10; arm1=1
    fi
  done
  if cmp -s "$W/n.exp.lit.$t" "$W/n.exp.eval.$t"; then
    echo "  IDENTICAL  EXPANDED  $t  (md5 $(md5sum < "$W/n.exp.eval.$t" | cut -c1-12))"
  else
    echo "  DIFFERS    EXPANDED  $t"
    diff "$W/n.exp.lit.$t" "$W/n.exp.eval.$t" | head -10; arm1=1
  fi
done

echo
echo "=============================================================="
echo "ARM 2 (BOTH-SIDED): the two targets must NOT be identical"
echo "=============================================================="
# PRINCIPLES 4: target A getting A's answer proves nothing unless B still gets
# B's.  Identical rules for both targets would mean one target is serving both
# -- a primary by another name -- and arm 1 would STILL pass.
if cmp -s "$W/n.exp.eval.$T1" "$W/n.exp.eval.$T2"; then
  echo "  FAIL: both targets produced IDENTICAL text -- N=2 collapsed to N=1"
  arm2=1
else
  echo "  OK: the targets differ, each naming its own subdir and --host"
  arm2=0
  for t in "$T1" "$T2"; do
    h=$(grep -o -- "--host=[^ ]*" "$W/n.exp.eval.$t" | head -1)
    d=$(grep -o -- "$t/libgcc" "$W/n.exp.eval.$t" | head -1)
    printf '      %-28s %-40s subdir=%s\n' "$t" "$h" "$d"
    # each target must name ITSELF, not the other one
    [ "$h" = "--host=$t" ] || { echo "      FAIL: wrong --host for $t"; arm2=1; }
    [ -n "$d" ] || { echo "      FAIL: $t does not name its own subdir"; arm2=1; }
  done
  # and neither may mention the other target at all
  if grep -q -- "$T2" "$W/n.exp.eval.$T1"; then
    echo "      FAIL: $T1's rules mention $T2 -- cross-contamination"; arm2=1
  fi
  if grep -q -- "$T1" "$W/n.exp.eval.$T2"; then
    echo "      FAIL: $T2's rules mention $T1 -- cross-contamination"; arm2=1
  fi
fi

echo
echo "=============================================================="
echo "ARM 3 (NEGATIVE CONTROL A): an EMPTY target list must FAIL BY NAME"
echo "=============================================================="
sed "s/^MT_TARGETS = .*/MT_TARGETS =/" "$W/probe-eval.mk" > "$W/probe-empty.mk"
sh "$SHELLSH" "cd $W && make -f probe-empty.mk all-target-libgcc-$T1" \
  > "$W/out.empty" 2> "$W/err.empty"
r_empty=$?
if [ $r_empty -eq 0 ]; then
  echo "  FAIL: empty list succeeded (rc=0) -- a loop that ran zero times"
  echo "        scored as a build.  This is the false green."
  arm3=1
elif grep -q "MT_TARGETS is empty" "$W/err.empty"; then
  echo "  OK: failed by name (rc=$r_empty):"
  grep "MT_TARGETS is empty" "$W/err.empty" | sed 's/^/      /'
  arm3=0
else
  echo "  WEAK: failed (rc=$r_empty) but NOT by name.  'No rule to make target'"
  echo "        is not a diagnosis:"
  sed 's/^/      /' "$W/err.empty" | head -5
  arm3=1
fi

echo
echo "=============================================================="
echo "ARM 4 (NEGATIVE CONTROL B): UNDER-QUOTING must be DETECTED"
echo "=============================================================="
# The design doc's stated failure mode.  Drop one level of $ doubling and
# require arm 1 to go RED.  If this does not change the output, arm 1 is not
# sensitive to quoting and its pass proves nothing.
sed 's/\$\$(srcdir)/$(srcdir)/g' "$W/probe-eval.mk" > "$W/probe-underq.mk"
if cmp -s "$W/probe-eval.mk" "$W/probe-underq.mk"; then
  echo "  FATAL: the injection changed nothing -- the control is vacuous"; arm4=1
else
  sh "$SHELLSH" "cd $W && make -p -f probe-underq.mk mtprobe_noop" \
    > "$W/p.underq" 2> "$W/perr.underq"
  extract_rule "$W/p.underq" "configure-target-libgcc-$T1" > "$W/rule.cfg.underq.raw"
  sh "$S/t113-norm.sh" "$W/rule.cfg.underq.raw" > "$W/rule.cfg.underq"
  if [ "$(wc -c < "$W/rule.cfg.underq")" -lt 200 ]; then
    echo "  OK: under-quoting produced NO rule at all -- detected (and note this"
    echo "      is exactly the silently-empty shape the design doc warns about)."
    arm4=0
  elif cmp -s "$W/n.cfg.lit.$T1" "$W/rule.cfg.underq"; then
    echo "  FAIL: under-quoted variant produced the CORRECT rule anyway."
    echo "        Arm 1 is insensitive to quoting; its pass proves nothing."
    arm4=1
  else
    echo "  OK: under-quoted variant differs from the control -- arm 1 is sensitive."
    echo "      first divergence:"
    diff "$W/n.cfg.lit.$T1" "$W/rule.cfg.underq" | cut -c1-200 | head -6 | sed 's/^/      /'
    arm4=0
  fi
fi

echo
echo "=============================================================="
printf 'VERDICT: arm1(identical)=%s arm2(both-sided)=%s arm3(empty-fails)=%s arm4(quoting-sensitive)=%s\n' \
  "$arm1" "$arm2" "$arm3" "$arm4"
if [ "$arm1" = 0 ] && [ "$arm2" = 0 ] && [ "$arm3" = 0 ] && [ "$arm4" = 0 ]; then
  echo "PASS: eval reproduces the shipped recipe text for N=2, both-sided,"
  echo "      empty list fails by name, and the comparison is demonstrably"
  echo "      sensitive to the quoting error that was the stated risk."
  exit 0
fi
echo "FAIL: see the arms above."
exit 1
