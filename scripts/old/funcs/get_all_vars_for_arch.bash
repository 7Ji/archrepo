get_all_vars_for_arch() { # 1: arrayname, 2: varname
	local aggregate l

	if array_build l "$2"; then
		aggregate+=("${l[@]}")
	fi

	if array_build l "${2}_${CARCH}"; then
		aggregate+=("${l[@]}")
	fi

	array_build "$1" "aggregate"
}

# get_all_sha256sums_for_arch() {
# 	get_all_vars_for_arch $1 sha256sums 
# }