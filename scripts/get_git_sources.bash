#!/bin/bash -e
# 1: pkgbuild
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source_makepkg_config
source $1
get_all_sources_for_arch 'all_sources'
for file in "${all_sources[@]}"; do
    if [[ $(get_protocol "${file}") != 'git' ]]; then continue; fi
    url=$(get_url "$file")
	url=${url#git+}
	url=${url%%#*}
	echo "${url%%\?*}"
done