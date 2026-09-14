#!/bin/bash
# Copies the dArkOS hooks into the PortMaster control folder.
#
# They cannot simply be shipped in the image: PortMaster's tools/installer.sh runs
# `$ESUDO rm -fRv "PortMaster" "PortMaster.sh"` in the control folder before unpacking,
# so anything put there at build time is gone after the first install and after every
# update. This runs at boot and again whenever the control folder's parent changes.

hooks_dir="/usr/local/share/dArkOS/portmaster"
# One location, not a search: /opt/system/Tools is a bind mount in dArkOS' fstab, so
# it is always present, and both the PortMaster installer and PortMaster's control.txt
# pick it as soon as it is - the installer takes "/opt/system/Tools" as the first
# branch of its fallback chain, control.txt resolves controlfolder the same way.
control_folder="/opt/system/Tools/PortMaster"

[ -d "${hooks_dir}" ] || exit 0
[ -f "${control_folder}/control.txt" ] || exit 0

for hook in "${hooks_dir}"/*.txt; do
  [ -f "${hook}" ] || continue
  target="${control_folder}/$(basename "${hook}")"
  cmp -s "${hook}" "${target}" || cp -f "${hook}" "${target}"
done
