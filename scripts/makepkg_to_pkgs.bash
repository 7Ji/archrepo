#!/bin/bash -e
# 1: path to build dir
pushd $1 &>/dev/null
# --holdver as we updated those repos before even deploying the PKGBUILDs
# --noextract as sources were extracted during need_build()
PKGEXT=.pkg.tar \
    makepkg --holdver --noextract --syncdeps --noconfirm
popd
# mv for atomic
buildname=$(<$1.buildname)
tempdir=$(mktemp -p pkgs -d XXXXXXXXXX)
mv "$1"/*"${PKGEXT}" "${tempdir}"/
mv "${tempdir}" pkgs/"${buildname}"
for pkg in pkgs/"${buildname}"/*; do
    ln -s ../"${buildname}"/$(basename "${pkg}") pkgs/updated
done