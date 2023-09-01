#!/bin/bash -e
# 1: path to build dir
pushd $1 &>/dev/null
# --holdver as we updated those repos before even deploying the PKGBUILDs
# --noextract as sources were extracted during need_build()
PKGEXT=.pkg.tar \
    makepkg --holdver --noextract --syncdeps --noconfirm
popd
# mv for atomic
pkgdir=pkgs/$(<"$1".build)
tempdir="${pkgdir}".temp
mv "$1"/*"${PKGEXT}" "${tempdir}"/
mv "${tempdir}" "${pkgdir}"
for pkg in "${pkgdir}"/*; do
    ln -sf ../"${buildname}"/$(basename "${pkg}") pkgs/updated
done