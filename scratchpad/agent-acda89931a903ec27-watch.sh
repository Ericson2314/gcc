#!/bin/sh
# Progress emitter for the overnight run.  One line per interval so a long
# silent `make' is not mistaken for a hang -- from outside they are identical,
# which is the same shape as everything else this project keeps meeting.
#
# It reports DRIVE-GONE when the driver has exited WITHOUT writing its stamp,
# because "still building" and "died twenty minutes ago" otherwise look the
# same.  That is not hypothetical here: the first launch of this build failed
# `mt_assert_builddir' instantly and sat looking like a slow configure.
B=/tmp/b-acda89931a903ec27
GAS=/tmp/gasbin-agent-acda89931a903ec27
while true; do
  if [ -f "$B/all-gcc.rc" ]; then
    cc1=NO; [ -x "$B/gcc/cc1" ] && cc1=yes
    echo "BUILD-FINISHED rc=$(cat "$B/all-gcc.rc") cc1=$cc1 load=$(cut -d' ' -f1 /proc/loadavg)"
    break
  fi
  alive=$(pgrep -cf 'mt-build.sh' 2>/dev/null || true)
  [ -n "$alive" ] || alive=0
  if [ "$alive" -eq 0 ]; then
    echo "BUILD-GONE without stamp; tail: $(tail -1 "$B/all-gcc.err" 2>/dev/null)"
    break
  fi
  # count objects across the WHOLE build dir: `all-gcc' spends its first
  # stretch in libiberty/libcpp/lto-plugin, so `$B/gcc/*.o' reads 0 for a
  # long time and that zero is not a stall.
  n=$(find "$B" -name '*.o' 2>/dev/null | wc -l)
  g=$(ls "$GAS" 2>/dev/null | grep -c -- '-as$')
  if [ -f "$B/conf.rc" ]; then
    echo "building conf=$(cat "$B/conf.rc") objs=$n gas=$g load=$(cut -d' ' -f1 /proc/loadavg) avail=$(free -g | awk '/Mem:/{print $7}')G"
  else
    echo "configuring gas=$g load=$(cut -d' ' -f1 /proc/loadavg)"
  fi
  sleep 480
done
