#!/bin/bash -e
# 1: pkgbuild
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source_makepkg_config
source $1
get_all_sources_for_arch 'all_sources'
# started=
for file in "${all_sources[@]}"; do
    if [[ $(get_protocol "${file}") != 'git' ]]; then continue; fi
    url=$(get_url "$file")
	url=${url#git+}
	url=${url%%#*}
	url=${url%%\?*}
    echo "${url}"
    # if [[ "${started}" ]]; then
    #     printf " %s" "${url}"
    # else
    #     started=yes
    #     printf "%s" "${url}"
    # fi
done
# echo