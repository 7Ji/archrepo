#!/bin/bash -e
# 1: pkgbuild name to enter
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source_makepkg_config
SRCDEST=$(readlink -f build/"$1")
source "${SRCDEST}"/PKGBUILD
# Download sources
HOLDVER=1
download_sources
# Extract sources
srcdir="${SRCDEST}"/src
mkdir "${srcdir}"
cd "${srcdir}"
extract_sources