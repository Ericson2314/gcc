#!/bin/sh
# Are the 45 per-target `readelf' binaries 45 DISTINCT builds, or one host
# binary copied under 45 names?
#
# This matters because `agent-acda89931a903ec27-fulltools.sh' states the
# refusal explicitly in its own header: "The tempting shortcut is to drop the
# host readelf in under a target name, since readelf reads every architecture.
# That is exactly the `one name, several authorities' defect the guard exists
# to detect, so it is refused here."
#
# If the md5s collapse to one, that refusal was written and not kept, and
# GUARD 3c's readelf arm is reading one authority under 45 names.
D=${1:-/tmp/gasbin-agent-acda89931a903ec27}
echo "== per-target readelf, distinct md5s:"
md5sum "$D"/*-readelf | awk '{print $1}' | sort -u | wc -l
echo "== named:"
ls "$D"/*-readelf | wc -l
echo "== host readelf md5 (if any on PATH):"
command -v readelf >/dev/null 2>&1 && md5sum "$(command -v readelf)" || echo "  no host readelf on PATH"
echo "== one sample's own target list:"
"$D"/xtensa-unknown-elf-readelf --version 2>&1 | head -2
echo "== does the xtensa-named readelf refuse a non-xtensa object?"
echo "  (a genuinely per-target readelf and a multi-arch one differ here)"
