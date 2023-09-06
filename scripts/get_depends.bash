#!/bin/bash -e
# 1: pkgbuild
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source_makepkg_config
source $1
for dep in "${depends[@]}" "${makedepends[@]}"; do
    echo "${dep}"
done