#!/bin/bash -e
# 1: pkgbuild name to enter, 2+: git repo hashes
LIBRARY="${LIBRARY:-/usr/share/makepkg}"
for lib in util source; do
    source "${LIBRARY}/${lib}".sh
done
source scripts/funcs/get_all_vars_for_arch.bash
source_makepkg_config
SRCDEST=$(readlink -f build/"$1")
source "${SRCDEST}"/PKGBUILD
get_all_sources_for_arch 'all_sources'
get_all_sha256sums_for_arch 'all_sha256sums'
git_hash_id=2
source_missing=
for file in "${all_sources[@]}"; do
    name=$(get_filename "$file")
    url=$(get_url "$file")
    case $(get_protocol "${file}") in
        git)
            src=sources/git/"${!git_hash_id}"
            git_hash_id=$(( $git_hash_id + 1 ))
            if [[ ! -d "${src}" ]]; then
                echo "ERROR: git source repo ${src} does not exist"
                exit 1
            fi
            ;;
        *)
            # Ignore files recorded in git tree
            if [[ -e "${SRCDEST}/${name}" ]]; then
                continue
            fi
            src=netfiles/"$1/${name}"
            if [[ ! -f "${src}" ]]; then
                source_missing='yes'
                continue
            fi
            ;;
    esac
    ln -s $(readlink -f "${src}") "${SRCDEST}/${name}"
done
if [[ -z "${source_missing}" ]]; then
    exit 0
fi
# Download sources
HOLDVER=1
download_sources
# Move back to our long-term storage
get_all_sources_for_arch 'all_sources'
for file in "${all_sources[@]}"; do
    name=$(get_filename "$file")
    url=$(get_url "$file")
    if [[ "${name}" == "${url}" ]]; then
        continue
    fi
    case $(get_protocol "${file}") in
        git) :;;
        *)
            src=netfiles/"$1/${name}"
            if [[ ! -e "${src}" ]]; then
                mv "${SRCDEST}/${name}" "${src}"
                ln -s $(readlink -f "${src}") "${SRCDEST}/${name}"
            fi
            ;;
    esac
done