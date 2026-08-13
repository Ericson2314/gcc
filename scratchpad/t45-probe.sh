#!/usr/bin/env bash
# Task #45 -- BEFORE-ARM: show, per target, which branch each of the three
# never-set config.gcc variables selects.
#
# config.gcc is SOURCED, exactly as gen-target-manifest.sh does it (same
# variable reset list, same `. ${srcdir}/config.gcc'), so the answer is the one
# the real configure gets and not a reconstruction.  The point of the arm is
# that ld_flavor / disable_initfini_array are UNSET here -- and are also unset
# in configure at the moment it sources config.gcc, which is the claim being
# demonstrated.
#
# Each probe prints the OBSERVABLE OUTPUT of the branch (extra_programs,
# gcc_cv_initfini_array), never the condition, so that it stays meaningful
# after the constant conditional is deleted.
#
# ---------------------------------------------------------------------------
# TWO INSTRUMENT BUGS FIXED, both of which made every line read "empty":
#
#  1. `set -u' inside the probe subshell.  config.gcc:306 reads ${target_min},
#     which nothing sets, so bash killed the subshell BEFORE the `eval echo'.
#     Every probe printed an empty value that looked exactly like a real
#     "branch not taken" answer.  It is also self-defeating: config.gcc
#     reading unset variables is the SUBJECT of this measurement, so the
#     instrument must not treat it as fatal.  `set -u' is therefore off in the
#     subshell and on in the driver.
#  2. `"$@"' for the extra assignments ran them as COMMANDS
#     (`ld_flavor=gnu: command not found') so the forced arms were never
#     forced and were identical to the unset arm by construction.  Assignments
#     now go through `eval'.
#
# Both failed towards "no difference between the arms", i.e. towards agreeing
# with the hypothesis.  Hence the non-vacuity assertion below: an arm that
# produces no non-empty observable anywhere is reported FATAL, never as a
# result.
#
#  3. `eval "echo \"\$$v\""' DOUBLE-expanded the value.  extra_programs is
#     literally `ld$(exeext) ar$(exeext)', so the second pass ran $(exeext) as
#     a COMMAND SUBSTITUTION and printed junk (`2128902v').  Values are now
#     read with bash indirect expansion ${!v}, which expands exactly once --
#     hence the #!/usr/bin/env bash above.
#
#  4. The triples were not canonicalised.  configure runs config.sub BEFORE
#     sourcing config.gcc (configure.ac:1558-1565); the harness did not, so
#     `msp430-elf' fell through every arm to config.gcc's final `*)' and
#     printed "*** Configuration msp430-elf not supported".  That is the
#     harness's own omission, NOT a statement about msp430 support.
# ---------------------------------------------------------------------------
set -u
srcdir=${srcdir:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-add93fb43c802e701/gcc}
[ -f "$srcdir/config.gcc" ] || { echo "FATAL: no config.gcc under srcdir=$srcdir"; exit 9; }
CONFIG_SUB=$srcdir/../config.sub
[ -x "$CONFIG_SUB" ] || { echo "FATAL: no executable config.sub at $CONFIG_SUB"; exit 9; }
err=/tmp/t45probe.err
nonvacuous=0

probe () {   # probe <triple> <var> [assignment ...]
  t=$1; v=$2; shift 2
  pre=$*
  # Canonicalise exactly as configure.ac:1558-1565 does, and fail by name if
  # the triple is not recognised rather than probing a bogus one.
  tc=`$CONFIG_SUB "$t" 2>>$err`
  if [ -z "$tc" ]; then
    echo "  $t: FATAL -- config.sub does not recognise this triple; not probed"
    sed 's/^/      /' < $err; return
  fi
  [ "$tc" = "$t" ] || echo "  (canonicalised $t -> $tc)"
  t=$tc
  : > $err
  out=`
    set +u
    target=$t
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2= extra_modes=
    TM_MULTILIB_CONFIG=
    extra_programs= gcc_cv_initfini_array=
    eval "$pre"
    . ${srcdir}/config.gcc 2>> $err > /dev/null || { echo "__FAILED__"; exit 0; }
    printf "MEASURED:%s" "${!v}"
  `
  case $out in
    __FAILED__) echo "  $t [${pre:-nothing forced}]: config.gcc FAILED; stderr:"
                sed 's/^/      /' < $err; return;;
    MEASURED:*) ;;
    *) echo "  $t [${pre:-nothing forced}]: FATAL -- probe produced no MEASURED line."
       echo "      This is an instrument failure, NOT an empty value.  stderr:"
       sed 's/^/      /' < $err; return;;
  esac
  val=${out#MEASURED:}
  [ -n "$val" ] && nonvacuous=$((nonvacuous+1))
  echo "  $t [${pre:-nothing forced}]: $v=[$val]"
  [ -s $err ] && { echo "      (config.gcc stderr:)"; sed 's/^/      /' < $err; }
  return 0
}

echo "=== ld_flavor arm (config.gcc *-*-*vms*): observable = extra_programs"
probe ia64-hp-openvms8.4 extra_programs
probe ia64-hp-openvms8.4 extra_programs ld_flavor=gnu

echo
echo "=== disable_initfini_array arm (config.gcc msp430-*-*): observable = gcc_cv_initfini_array"
probe msp430-elf gcc_cv_initfini_array
probe msp430-elf gcc_cv_initfini_array disable_initfini_array=yes
echo "  (enable_initfini_array=no is the name autoconf DOES set from"
echo "   --disable-initfini-array; identical to the unset line means the"
echo "   option cannot reach this code at all)"
probe msp430-elf gcc_cv_initfini_array enable_initfini_array=no

echo
echo "=== x86_with_multilib arm (config.gcc i[34567]86-*-linux*)"
echo '    ${x86_with_multilib} appears ONLY in two rejection messages, and the'
echo '    correct name for the value being rejected is ${x86_multilib} (the'
echo "    loop variable).  Upstream's misspelling: identical at"
echo "    c31b7a09eea:gcc/config.gcc:2060 and :2130."
echo
echo "    But on THIS branch the rejection arm is UNREACHABLE, so the message"
echo "    is never printed at all.  config.gcc:237 assigns"
echo "    with_multilib_list=default unconditionally (ours -- upstream has no"
echo "    such assignment), so x86_multilibs is always \"default\", which is"
echo "    rewritten to \"m64,m32\", and every element of that passes the case."
echo "    A caller-supplied value cannot survive line 237 to reach the arm."
echo
echo "    The probe below forces a bogus --with-multilib-list and shows the"
echo "    rejection does NOT fire: expected rc=0 and no message.  Note that if"
echo "    it ever did fire, config.gcc echoes it to STDOUT, not stderr -- the"
echo "    same defect the riscv comment at config.gcc:2623 already records"
echo "    (\"an empty message because the echo went to stdout\")."
msg () {   # msg <triple> <multilib-list>
  o=/tmp/t45probe.out; : > $o; : > $err
  (
    set +u
    target=`$CONFIG_SUB "$1"`
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2= extra_modes=
    TM_MULTILIB_CONFIG= extra_programs= gcc_cv_initfini_array=
    with_multilib_list=$2
    enable_backends=all
    . ${srcdir}/config.gcc > $o 2> $err
  )
  rc=$?
  echo "  $1 with_multilib_list=$2 -> rc=$rc"
  if [ -s $o ]; then echo "    stdout: $(sed 's/^/            /' < $o)"; else echo "    stdout: <EMPTY>"; fi
  if [ -s $err ]; then echo "    stderr: $(sed 's/^/            /' < $err)"; else echo "    stderr: <empty>"; fi
}
msg i686-pc-linux-gnu bogusmultilib
echo "  ...and the positive control: the SAME arm DOES reject when the pin at"
echo "     config.gcc:237 is bypassed, proving the arm exists and the probe can"
echo "     see it fire.  (Bypassed by setting the loop's own input, which is"
echo "     what line 237 would otherwise have overwritten.)"
msgpin () {
  o=/tmp/t45probe.out; : > $o; : > $err
  (
    set +u
    target=`$CONFIG_SUB i686-pc-linux-gnu`
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2= extra_modes=
    TM_MULTILIB_CONFIG= extra_programs= gcc_cv_initfini_array=
    enable_backends=all
    # Read config.gcc with line 237's pin removed, so the caller's value
    # survives to the arm.  Nothing else is altered.
    sed 's/^with_multilib_list=default$/: pin removed by t45-probe.sh/' \
      ${srcdir}/config.gcc > /tmp/t45-config.gcc
    with_multilib_list=bogusmultilib
    . /tmp/t45-config.gcc > $o 2> $err
  )
  echo "     rc=$?"
  if [ -s $o ]; then echo "     stdout: $(cat $o)"; else echo "     stdout: <EMPTY>"; fi
  if [ -s $err ]; then echo "     stderr: $(cat $err)"; else echo "     stderr: <empty>"; fi
}
msgpin

echo
echo "=== non-vacuity: probes that returned a NON-EMPTY observable: $nonvacuous"
if [ "$nonvacuous" -lt 1 ]; then
  echo "FATAL: every probe was empty.  A run in which no branch ever produces"
  echo "an observable cannot distinguish 'branch not taken' from 'instrument"
  echo "broken'.  This run proves nothing."
  exit 9
fi
