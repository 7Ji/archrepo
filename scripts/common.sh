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

if [[ "${SCRIPT_DEBUG}" ]]; then
assert_declared() { #1: arg name
    local bad=
    while (( $# > 0 )); do
        if [[ ! -v $1 ]]; then
            log fatal "Variable '$1' is not declared"
            bad='yes'
        fi
        declare -n var="$1"
        if [[ -z "${var}" ]]; then
            log fatal "Variable '$1' is empty"
            bad='yes'
        fi
        shift
    done
    if [[ "${bad}" ]]; then
        log fatal 'Declaration assertion failed'
        exit 1
    fi
}
else
assert_declared() { :; }
fi

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
    local commit_remote commit_local idle integ_self args_arb

    args_arb=(--noclean "${args_builder[@]}" "${config}")
    integ_self=$(sha256sum $(readlink -f -- "$0")) # Both checksum and path
    enable sleep
    idle=60
    while true; do
        commit_remote=$(git ls-remote origin master)
        commit_remote="${commit_remote::40}"
        commit_local=$(git rev-parse master)
        if [[ "${commit_remote}" == "${commit_local}" ]]; then
            if (( "${idle}" < 60 )); then
                let idle++
                sleep 60
                continue
            fi
        else
            warn "Updating ${commit_local} -> ${commit_remote}"
            git fetch origin '+refs/heads/master:refs/remotes/origin/master'
            git reset --hard origin/master
            if [[ $(sha256sum $(readlink -f -- "$0")) != "${integ_self}"* ]]; then
                warn 'Daemon script updated, exit to let outer supervisor decide whether to continue'
                exit 0
            fi
        fi
        idle=0
        info "Starting builder with arguments: ${args_arb[@]}"
        if sudo ./arb "${args_arb[@]}"; then
            info 'Successfullly built, doing full update'
            if ! full_update; then
                error 'Full update failed, maintainer attention needed'
                exit 1
            fi
            info 'Full update successful'
        else
            error 'Failed to build, checking if partial update needed'
            if [[ "$(ls -A pkgs/updated)" ]]; then
                warn 'Found built packages although build was failed, doing partial update'
                if ! partial_update; then
                    error 'Failed to partial update after a failed build with built packages, refuse to continue'
                    exit 1
                fi
                info 'Partial update successful, next build will be triggered immediately'
                idle=60
            fi
        fi
    done
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
                repo="$2"
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

remote_update() {
    assert_declared rsync_parent repo arch

    rsync --recursive --copy-links --update --delete --verbose releases/ "${rsync_parent}/${repo}/${arch}/"
}

shopt -s extglob # Because Bash checks glob syntax in function definition

full_update() {
    assert_declared repo arch rsync_parent

    local link_target link_path file_name db

    rm -rf releases
    mkdir releases
    for link_path in pkgs/latest/*; do
        link_target=$(readlink "${link_path}") || continue
        file_name="${link_target##*/}"
        file_name="${file_name/:/.}"
        ln -s ../pkgs/"${link_target:3}"  releases/"${file_name}"
    done
    cd releases
    shopt -s extglob
    repo-add --verify --sign "${repo}".db.tar.zst *.pkg.tar!(*.sig)
    shopt -u extglob
    cd - > /dev/null
    remote_update
}

partial_update() {
    assert_declared repo arch rsync_parent

    local link_target link_path file_name db pkgs_to_add=() dir_db list_pkgs_to_keep

    for link_path in pkgs/updated/*; do
        [[ ! -f ${link_path} ]] && continue
        link_target=$(readlink "${link_path}") || continue
        file_name="${link_target##*/}"
        file_name="${file_name/:/.}"
        ln -sf ../pkgs/"${link_target:3}"  releases/"${file_name}"
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
    shopt -s extglob
    for link_path in *.pkg.tar!(*.sig); do
        grep -q '^'"${link_path}"'$' "${list_pkgs_to_keep}" && continue
        rm -f "${link_path}"{,.sig}
    done
    shopt -u extglob
    rm -f "${list_pkgs_to_keep}"
    cd - > /dev/null
    remote_update
}

shopt -u extglob # Because Bash checks glob syntax in function definition

argparse_update() {
    repo=7Ji
    arch=aarch64
    rsync_parent='/srv/http/repo'

    while (( $# > 0 )); do
        case "$1" in
            --repo)
                repo="$2"
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

cli_partial_update() {
    local arch= rsync_parent=

    argparse_update "$@"
    partial_update
}

applet="${0##*/}"
case "${applet}" in
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
        log fatal "Unknown applet '${applet}'"
        ;;
esac