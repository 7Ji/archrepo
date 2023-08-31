set git_proxy socks5://xray.lan:1080
# Do not start new build job after 1-min loadavg is greater than this
set load_max 8
# Do not touch these constants
set len_ck 10
set len_md5 32
set len_sha1 40
set len_sha224 56
set len_sha256 64
set len_sha384 96
set len_sha512 128
set len_b2 128

function ensure_dir
    if test ! -d $argv[1]
        rm -rf $argv[1]
        if ! mkdir -p $argv[1]
            printf "Failed to ensure folder '%s'\n" $argv[1]
            return 1
        end
    end
end

function ensure_dirs
    rm -rf build pkgs/{latest,updated}
    for dir in build sources/{git,file-{ck,md5,sha{1,224,256,384,512},b2}} pkgs/{latest,updated}
        if ! ensure_dir $dir
            printf "Failed to ensure work folder '%s'\n" $argv[1]
            return 1
        end
    end
end

function xxh3sum_64bit
    printf "%s" "$argv" | xxhsum -H3 | string split --fields 4 ' '
end

function init_repo # 1: dir, 2: url
    if test -z "$argv[1..2]"
        echo "Dir and URL not set"
        return 1
    end
    rm -rf "$argv[1]"
    mkdir "$argv[1]"
    mkdir "$argv[1]"/{objects,refs}
    echo 'ref: refs/heads/master' > "$argv[1]/HEAD"
    printf '[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = true\n[remote "origin"]\n\turl = %s\n\tfetch = +refs/*:refs/*\n' \
        "$argv[2]" > "$argv[1]/config"
end

function update_repo # 1: dir
    # TODO: Remove me! This is a temporary early-quit flag to save debugging time
    return 0
    if ! git --git-dir "$argv[1]" remote update
        if test -z "$git_proxy"
            printf "Failed to update repo '%s'\n" $argv[1]
            return 1
        end
        printf "Failed to update repo '%s', using proxy '%s' to retry\n" \
                "$argv[1]" "$git_proxy"
        if ! git -c http.proxy="$git_proxy" --git-dir "$argv[1]" remote update
            printf "Failed to update repo '%s' using proxy '%s'\n" \
                "$argv[1]" "$git_proxy"
            return 1
        end
    end
end

function sync_repo # 1: dir, 2: url. Init if not found, then update
    if test -z "$argv[1..2]"
        echo "Dir and URL not set"
        return 1
    end
    if test ! -d "$argv[1]"
        if ! init_repo "$argv[1]" "$argv[2]"
            printf "Failed to init non-existing repo at '%s' for '%s'\n" \
                    $argv[1..2]
            return 1
        end
    end
    if ! update_repo $argv[1]
        printf "Failed to update repo at '%s' to sync with '%s'\n" \
            $argv[1] $argv[2]
        return 1
    end
end

function read_pkgbuilds # 1: config
    set --global list (grep -o '^ - [a-Z0-9_-]\+: [a-Z0-9_:/.-]\+'  "$argv[1]")
    set --global pkgs (string replace : '' (string split --no-empty --fields 2 ' ' $list))
    set --global urls (string split --no-empty --fields 3 ' ' $list)
    set --global hashes (for url in $urls; xxh3sum_64bit $url; end)
    set --global pkg_cnt (count $pkgs)
    if test $pkg_cnt -eq 0
        echo "No packages defined"
        return 1
    end
end

function sync_pkgbuilds
    for i in (seq 1 $pkg_cnt)
        printf "Syncing PKGBUILD '%s' with URL '%s', hash '%s'\n" $pkgs[$i] $urls[$i] $hashes[$i]
        sync_repo sources/git/$hashes[$i] $urls[$i]
    end
end

function dump_pkgbuild # 1: git dir 2: output
    if ! git --git-dir "$argv[1]" cat-file blob master:PKGBUILD > "$argv[2]"
        printf "Failed to dump PKGBUILD from '%s'\n" "$argv[1]"
        return 1
    end
end

function get_file_cache_paths # 1: type, 2+: name
    for arg in $argv[2..]
        set name (string split --max 1 --fields 1 ' ' "$arg")
        # if test "$name" != ''
        echo sources/file-"$argv[1]/$name"
        # end
    end
end

function predownload_sources
    set pkgbuild "$(mktemp)"
    set git_urls
    for integ in {ck,md5,sha{1,224,256,384,512},b2}
        set {$integ}s
    end
    for hash in $hashes
        if ! dump_pkgbuild sources/git/"$hash" "$pkgbuild"
            printf "Failed to get PKGBUILD from '%s' to parse vcs sources\n" \
                    "$hash"
            return 1
        end
        if ! set --append git_urls (scripts/get_git_sources.bash "$pkgbuild")
            printf "Failed to parse git sources from '%s'\n" "$hash"
            return 1
        end
        if ! set files (scripts/get_file_sources.bash "$pkgbuild")
            printf "Failed to parse file sources from '%s'\n" "$hash"
            return 1
        end
        if test (count $files) -lt 2
            continue
        end
        switch $files[1]
        case ''
            echo "Warning: no integrity found, cannot predownload"
        case ck
            set --append cks $files[2..]
        case md5
            set --append md5s $files[2..]
        case sha1
            set --append sha1s $files[2..]
        case sha224
            set --append sha224s $files[2..]
        case sha256
            set --append sha256s $files[2..]
        case sha384
            set --append sha384s $files[2..]
        case sha512
            set --append sha512s $files[2..]
        case b2
            set --append b2s $files[2..]
        case '*'
            printf "Invalid integrity "
            return 1
        end
    end
    set git_urls (printf '%s\n' $git_urls | sort | uniq)
    set git_hashes (for git_url in $git_urls; xxh3sum_64bit $git_url; end)

    set files
    set urls

    for integ in {ck,md5,sha{1,224,256,384,512},b2}
        set sums {$integ}s
        set len_sum len_$integ
        if test (count $$sums) -gt 0
            set $sums (printf '%s\n' $$sums | sort | uniq --check-chars $$len_sum)
            set --append files (get_file_cache_paths $integ $$sums)
            set --append urls (string split --max 1 --fields 2 ' ' $$sums)
        end
    end
    echo (count $files)
    echo (count $urls)
    rm -f $pkgbuild
end

# function get_git_sources # 1: pkgbuild
#     set -l pkgbuild (mktemp)
#     if ! dump_pkgbuild "$argv[1]" "$pkgbuild"
#         printf "Failed to get PKGBUILD from '%s' to parse vcs sources\n" \
#                 "$argv[1]"
#         return 1
#     end
#     ./scripts/get_git_sources.bash "$pkgbuild"
#     rm -f "$pkgbuild"
# end

# function get_git_hashes # @: sources
#     if test (string length "$argv") -eq 0
#         echo
#         return 0
#     end
#     for arg in (string split ' ' $argv)
#         printf '%s ' (xxh3sum_64bit $arg)
#     end
#     echo
# end

# function get_file_sources  # 1: pkgbuild
#     set -l pkgbuild (mktemp)
#     if ! dump_pkgbuild "$argv[1]" "$pkgbuild"
#         printf "Failed to get PKGBUILD from '%s' to parse file sources\n" \
#                 "$argv[1]"
#         return 1
#     end
#     ./scripts/get_file_sources.bash "$pkgbuild"
#     rm -f "$pkgbuild"
# end

function prepare_build # 1: pkg name 2: hash 3: git source hashes
    set -l build_dir build/"$argv[1]"
    rm -rf "$build_dir"
    # Don't use -p here to save extra syscall, caller should've created build
    mkdir "$build_dir"
    # mkdir -p netfiles/"$argv[1]"
    if ! git --git-dir sources/git/"$argv[2]" --work-tree "$build_dir" checkout -f master
        printf "Failed to checkout to builddir '%s'\n" "$argv[1]"
        return 1
    end
    if ! ./scripts/prepare_sources.bash $argv[1] (string split ' ' $argv[3])
        printf "Failed to prepare sources for '%s'\n" "$argv[1]"
        return 1
    end
end

# Config must be given as argv[1]
if test -z $argv[1]
    echo "Config file not set"
    exit 1
end 
if ! test -f $argv[1]
    printf "Config file '%s' does not exist\n" $argv[1]
    exit 1
end
if ! ensure_dirs
    echo "Failed to ensure top-level work dirs"
    exit 1
end

# Parse the config to get a list of packages
set list
set pkgs
set urls
set hashes
set pkg_cnt
if ! read_pkgbuilds $argv[1]
    echo "Failed to read PKGBUILDs"
    exit 1
end

sync_pkgbuilds

if ! predownload_sources
    echo "Failed to pre-download sources"
    exit 1
end

exit 0

# If there's any package using git repos, we manage the sources independent from makepkg
# set git_sources (for hash in $hashes; get_git_sources sources/git/$hash; end)
# set git_hashes (
#     for git_source in $git_sources
#         get_git_hashes $git_source
#     end
# )
# Update all git sources, without duplication
# set all_git_sources (string split ' ' $git_sources | grep -v '^$' | uniq)
# set all_git_hashes (string split ' ' $git_hashes | grep -v '^$' | uniq)
# set git_cnt (count $all_git_sources)
# for i in (seq 1 $git_cnt)
#     printf "Updating git source '%s', hash '%s'\n" $all_git_sources[$i] $all_git_hashes[$i]
#     if ! sync_repo sources/git/$all_git_hashes[$i] $all_git_sources[$i];
#         printf "Failed to update git source '%s'\n" $all_git_sources[$i]
#         exit 1
#     end
# end

# for i in (seq 1 $pkg_cnt)
#     # Checkout the PKGBUILD, and download missing sources, and move sources to our
#     # long-term storage after downloing them
#     if ! prepare_build "$pkgs[$i]" $hashes[$i] "$git_hashes[$i]"
#         printf "Failed to prepare to build '%s'\n" "$pkgs[$i]"
#         exit 1
#     end
#     printf "Prepared '%s'\n" "$pkgs[$i]"
#     # After the above step, all sources should exist, check if it needs building
#     # If not, the build dir would be removed
#     ./scripts/need_build.bash "$pkgs[$i]" (git --git-dir sources/git/$hashes[$i] rev-parse master)
#     switch "$status"
#         case 0
#             printf "Should build '%s'\n" "$pkgs[$i]"
#         case 255
#             printf "No need to build '%s', removing its build dir\n" "$pkgs[$i]"
#             rm -rf build/$pkgs[$i]
#         case '*'
#             printf "Error encountered when checking whether we should build '%s'\n" \
#                 $pkgs[$i]
#             exit 1
#     end
# end
# exit 0

# set -x PKGEXT .pkg,tar
# for i in (seq 1 $pkg_cnt)
#     if test -d build/$pkgs[$i]
#         while test (string split --fields 1 ' ' (cat /proc/loadavg)) -ge $load_max
#             # Wait for CPU resource
#             # printf "Under heavy load, waiting for CPU resource before starting to build '%s'..." $pkgs[$i]
#             sleep 5
#         end
#         printf "Started building work for '%s'\n" $pkgs[$i]
#         ./scripts/makepkg_to_pkgs.bash build/$pkgs[$i] &
#     end
# end
# wait

# for file in build/*.buildname
#     set -l buildname (cat $file)
#     for pkg in pkgs/$buildname/*
#         ln -s ../$buildname/(basename $pkg) pkgs/latest/
#     end
# end