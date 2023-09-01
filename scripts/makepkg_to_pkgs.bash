#!/bin/bash -e
# 1: path to build dir
pushd $1 &>/dev/null
# --holdver as we updated those repos before even deploying the PKGBUILDs
# --noextract as sources were extracted during need_build()
PKGEXT=.pkg.tar \
    makepkg --holdver --noextract --syncdeps --noconfirm
popd &>/dev/null
# mv for atomic
buildid="$(<"$1".id)"
pkgdir=pkgs/"${buildid}"
tempdir="${pkgdir}".temp
mkdir "${tempdir}"
mv "$1"/*.pkg.tar "${tempdir}"/
mv "${tempdir}" "${pkgdir}"
for pkg in "${pkgdir}"/*; do
    ln -sf ../"${buildid}"/$(basename "${pkg}") pkgs/updated/
done