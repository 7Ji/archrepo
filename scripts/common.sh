#!/bin/bash

log() { #1: level, #2: content
    printf -- '[%s] %s\n' "$1" "$2"
}

info() {
    log INFO "$@"
}

warn() {
    log WARN "$@"
}

error() {
    log ERROR "$@"
}

fatal() {
    log FATAL "$@"
}

assert_declared() { #1: arg name
    while (( $# > 0 )); do
        if [[ ! -v $1 ]]; then
            log fatal "Assertion failed: variable '$1' is not declared"
            exit 1
        fi
        shift
    done
}

default_or() { #1: value, #2: default
    declare -n var="$1"
    if [[ -z "${var}" ]]; then
        printf -- '%s' "$2"
    else
        printf -- '%s' "${var}"
    fi
}

build_daemon() {
    assert_declared repo arch config rsync_parent args_builder

}

argparse_build_daemon() {
    repo=7Ji
    arch=aarch64
    config=config.yaml
    rsync_parent='/srv/http/repo'
    args_builder=()
    while (( $# > 0 )); do
        case "$1" in
            --repo)
                repo="2"
                shift
            ;;
            --arch)
                arch="$2"
                shift
            ;;
            --config)
                config="$2"
                shift
            ;;
            --rsync-parent)
                rsync_parent="$2"
                shift
            ;;
            --)
                args_builder=("${@:2}")
                return
            ;;
        esac
        shift
    done
}

cli_build_daemon() { 
    local repo arch config rsync_parent args_builder
    argparse_build_daemon "$@"
    build_daemon
}

full_update() {
    assert_declared repo arch rsync_parent
    local link_target link_path file_name db
    rm -rf releases
    mkdir releases
    for link_path in pkgs/latest/*; do
        link_target=$(readlink "${link_path}") || continue
        file_name="${link_target##*/}"
        file_name="${link_target/:/.}"
        ln -s ../pkgs/"${link_target:3}"  releases/"${file_name}"
    done
    cd releases
    shopt -s extglob
    repo-add --verify --sign "${repo}".db.tar.zst *.pkg.tar!(*.sig)
    shopt -u extglob
    cd -
}

argparse_update() {
    repo=7Ji
    arch=aarch64
    rsync_parent='/srv/http/repo'
    while (( $# > 0 )); do
        case "$1" in
            --repo)
                repo="2"
                shift
            ;;
            --arch)
                arch="$2"
                shift
            ;;
            --rsync-parent)
                rsync_parent="$2"
                shift
            ;;
        esac
        shift
    done
}

cli_full_update() {
    local arch= rsync_parent=
    argparse_update "$@"
    full_update
}

partial_update() {
    assert_declared repo arch rsync_parent
    local link_target link_path file_name db pkgs_to_add=() dir_db list_pkgs_to_keep
    for link_path in pkgs/updated/*; do
        [[ ! -f ${link_path} ]] && continue
        link_target=$(readlink "${link_path}") || continue
        file_name="${link_target##*/}"
        file_name="${link_target/:/.}"
        ln -sf ../pkgs/"${link_target:3}" releases/"${file_name}"
        [[ "${file_name}" == *.sig ]] && continue
        pkgs_to_add+=("${file_name}")
    done
    cd releases
    repo-add --verify --sign "${repo}".db.tar.zst "${pkgs_to_add[@]}"
    dir_db=$(mktemp -d)
    tar -C "${dir_db}" -xvf "${repo}".db.tar.zst
    list_pkgs_to_keep=$(mktemp)
    sed -n '/%FILENAME%/{n;p;}' "${dir_db}"/*/desc | sort | uniq > "${list_pkgs_to_keep}"
    rm -rf "${dir_db}"
    for link_path in *.pkg.tar!(*.sig); do
        grep -q '^'"${link_path}"'$' "${list_pkgs_to_keep}" && continue
        rm -f "${link_path}"{,.sig}
    done
    rm -f "${list_pkgs_to_keep}"
    cd -
}

cli_partial_update() {
    local arch= rsync_parent=
    argparse_update "$@"
    partial_update
}

applet="${0##*/}"
case "$0" in
    build_daemon)
        cli_build_daemon "$@"
        ;;
    full_update)
        cli_full_update "$@"
        ;;
    partial_update)
        cli_partial_update "$@"
        ;;
    *)
        log fatal "Unknown applet '$0'"
        ;;
esac