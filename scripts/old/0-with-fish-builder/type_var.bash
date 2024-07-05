#!/bin/bash -e
# 1: path to bash script to source, could be PKGBUILD, 2: name
source "$1" &>/dev/null
type -t "$2"
