#!/bin/bash -e
# 1: pkgbuild name to enter, 2: commit hash
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source_makepkg_config
SRCDEST=$(readlink -f build/"$1")
source "${SRCDEST}"/PKGBUILD
get_all_sources_for_arch 'all_sources'
srcdir="${SRCDEST}"/src
mkdir "${srcdir}"
source_extracted=''
buildname="$1-$2"
if [[ $(type -t pkgver) == 'function' ]]; then
    echo "Extracting sources to run pkgver()"
    extract_sources
    source_extracted='yes'
    pushd "${srcdir}" &>/dev/null
    buildname+="-$(pkgver)"
    popd &>/dev/null
fi
echo "${buildname}" > build/$1.buildname
pkgdir=pkgs/"${buildname}"
if [[ -d "${pkgdir}" ]] && compgen -G "${pkgdir}"/* &>/dev/null; then
    # No need to build
    exit 255 # -1
fi
# Need to build
if [[ -z "${source_extracted}" ]]; then
    extract_sources
fi
# Only remove, do not create it, we'll create later a temp dir and do atomic mv
rm -rf "${pkgdir}"