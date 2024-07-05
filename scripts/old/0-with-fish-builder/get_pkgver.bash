#!/bin/bash -e
# 1: pkgdir
srcdir=$(readlink -f build/"$1"/src)
cd "${srcdir}"
source ../PKGBUILD
pkgver