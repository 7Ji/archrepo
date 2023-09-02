#!/bin/bash -e
# 1: path to build dir
buildid="$(<"$1".id)"
pkgdir=pkgs/"${buildid}"
tempdir="${pkgdir}".temp
rm -rf "${tempdir}"
mkdir "${tempdir}"
PKGDEST="$(readlink -f "${tempdir}")"
pushd $1 &>/dev/null
# --holdver as we updated those repos before even deploying the PKGBUILDs
# --noextract as sources were extracted during need_build()
PKGEXT=.pkg.tar PKGDEST="${PKGDEST}"  \
    makepkg --holdver --noextract --syncdeps --noconfirm -A
popd &>/dev/null
# mv for atomic
mv "${tempdir}" "${pkgdir}"
for pkg in "${pkgdir}"/*; do
    ln -sf ../"${buildid}"/$(basename "${pkg}") pkgs/updated/
done
rm -rf "$1"{,.id}