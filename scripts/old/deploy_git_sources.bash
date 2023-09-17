#!/bin/bash -e
# 1: pkgname, 2+: hashes of git sources
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source_makepkg_config
SRCDEST=build/"$1"
source $SRCDEST/PKGBUILD
get_all_sources_for_arch 'all_sources'
i=2
for file in "${all_sources[@]}"; do
    if [[ $(get_protocol "${file}") != 'git' ]]; then continue; fi
    name=$(get_filename "$file")
    ln -s ../../sources/git/"${!i}" "$SRCDEST/$name"
    i=$(( i + 1 ))
done