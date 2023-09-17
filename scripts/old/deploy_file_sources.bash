#!/bin/bash -e
# 1: pkgname
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source scripts/funcs/get_all_vars_for_arch.bash
source_makepkg_config
SRCDEST=build/"$1"
source "${SRCDEST}"/PKGBUILD
get_all_sources_for_arch 'all_sources'
integ=''
for _integ in {ck,md5,sha{1,224,256,384,512},b2}; do
    sums="${_integ}sums"
    if [[ "${!sums}" ]]; then
        integ="${_integ}"
    fi
done
if [[ -z "${integ}" ]]; then
    # No integrity check to use, we can't guarantee cached sources are OK
    exit 0
fi

get_all_vars_for_arch 'all_checksums' "${integ}"sums
if [[ ${#all_sources[@]} != ${#all_checksums[@]} ]]; then
    printf "ERROR: sources length (%u) and sha256sums length (%u) mismatch:\n" \
        ${#all_sources[@]}  ${#all_checksums[@]}
    printf '%s\n' "${all_sources[@]}"
    exit 1
fi
i=0
for file in "${all_sources[@]}"; do
    case $(get_protocol "${file}") in
        bzr|fossil|git|hg|svn|local)
            # Ignore vcs and local sources
            i=$(( i + 1 ))
            continue
            ;;
    esac
    cksum="${all_checksums[$i]}"
    if [[ "${cksum}" != 'SKIP' ]]; then
        ln -s ../../sources/file-"$integ/$cksum" "$SRCDEST/$(get_filename "${file}")"
    fi
    i=$(( i + 1 ))
done