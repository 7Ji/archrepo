# Use the proxy to fetch from git server, after a failed attempt without proxy
# Default: (empty), set with --git-proxy
set git_proxy ''
# Hold the PKGBUILDs and all git sources, do not update them
# Default: 0, for disabled, set with --holdver to enable it
set holdver 0
# Do not start new build job after 1-min loadavg is greater than this, default 8, set with --load_max
# Default: 8, for 8.00 load, 1.00 = 1 core, set with --load-max
set load_max 8

# DO NOT touch these constants!
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
    rm -rf $argv[1]
    mkdir $argv[1]
    mkdir $argv[1]/{objects,refs}
    echo 'ref: refs/heads/master' > $argv[1]/HEAD
    printf '[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = true\n[remote "origin"]\n\turl = %s\n\tfetch = +refs/*:refs/*\n' \
        $argv[2] > $argv[1]/config
end

function repo_healthy
    if test "$(git --git-dir $argv[1] rev-parse HEAD)" = 'HEAD'
        return 1
    else
        return 0
    end
end

function git_update # 1: git dir 2: whether to update HEAD, 3: addtional arg (probably proxy)
    if ! git --git-dir $argv[1] $argv[3..] remote update --prune
        printf "Failed to update git repo '%s'\n" $argv[1]
        return 1
    end
    if test $argv[2] != 'yes'
        return 0
    end
    if ! set ref "$(
        git --git-dir $argv[1] $argv[3..] ls-remote --symref origin HEAD | 
        string match --regex 'refs/heads/[a-zA-Z0-9._/-]+')"
        printf "Failed to get remote HEAD of repo '%s'\n" $argv[1]
        return 1
    end
    if ! git --git-dir $argv[1] symbolic-ref HEAD $ref
        printf "Failed to set local HEAD of repo '%s' to '%s'\n" $argv[1] $ref
        return 1
    end
end

function update_repo # 1: dir 2: whether to update head
    if test $holdver -eq 1
        if repo_healthy $argv[1]
            # printf "Holding version for healthy repo '%s'\n" $argv[1]
            return 0
        else
            printf "Holdver set but repo '%s' not healthy, need to update it\n" \
                $argv[1]
        end
    end
    if ! git_update $argv[1..2]
        if test -z "$git_proxy"
            printf "Failed to update repo '%s'\n" $argv[1]
            return 1
        end
        printf "Failed to update repo '%s', using proxy '%s' to retry\n" \
                $argv[1] "$git_proxy"
        if ! git_update $argv[1..2] -c http.proxy="$git_proxy"
            printf "Failed to update repo '%s' using proxy '%s'\n" \
                $argv[1] "$git_proxy"
            return 1
        end
    end
end

function sync_repo # 1: dir, 2: url. 3: whether to update HEAD. Init if not found, then update
    if test -z "$argv[1..2]"
        echo "Dir and URL not set"
        return 1
    end
    if test ! -d $argv[1]
        if ! init_repo $argv[1] $argv[2]
            printf "Failed to init non-existing repo at '%s' for '%s'\n" \
                    $argv[1..2]
            return 1
        end
    end
    if ! update_repo $argv[1] $argv[3]
        printf "Failed to update repo at '%s' to sync with '%s'\n" \
            $argv[1] $argv[2]
        return 1
    end
end

function read_pkgbuilds # 1: config
    set --global list (grep -o '^ - [a-Z0-9_-]\+: [a-Z0-9_:/.-]\+'  $argv[1])
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
        sync_repo sources/git/$hashes[$i] $urls[$i] no
    end
end

function dump_pkgbuild # 1: git dir 2: output
    if ! git --git-dir $argv[1] cat-file blob master:PKGBUILD > $argv[2]
        printf "Failed to dump PKGBUILD from '%s' to '%s'\n" $argv[1] $argv[2]
        return 1
    end
end

function prepare_git_sources
    # do this alone first, so all git sources are up-to-date
    set pkgbuild "$(mktemp)"
    set git_urls
    for i in (seq 1 $pkg_cnt)
        set hash $hashes[$i]
        set pkg $pkgs[$i]
        if ! dump_pkgbuild sources/git/$hash $pkgbuild
            printf "Failed to get PKGBUILD from '%s' to parse vcs sources\n" \
                    $pkg
            rm -f $pkgbuild
            return 1
        end
        if ! set --append git_urls (scripts/get_git_sources.bash $pkgbuild)
            printf "Failed to parse git sources from '%s'\n" $pkg
            rm -f $pkgbuild
            return 1
        end
    end
    rm -f $pkgbuild
    if test (count $git_urls) -eq 0
        return 0
    end
    set git_urls (printf '%s\n' $git_urls | sort | uniq)
    for git_url in $git_urls
        printf "Syncing git source '%s'\n" $git_url
        if ! sync_repo sources/git/(xxh3sum_64bit $git_url) $git_url yes
            printf "Failed to sync git source '%s'\n" $git_url
            return 1
        end
    end
end

function deploy_git_sources # 1: pkgname
    set pkgbuild build/$argv[1]/PKGBUILD
    if ! set git_urls (scripts/get_git_sources.bash $pkgbuild)
        printf "Failed to parse git sources from '%s'\n" $argv[1]
        return 1
    end
    set git_hashes
    for git_url in $git_urls
        set git_hash "$(xxh3sum_64bit $git_url)"
        set git_dir sources/git/$git_hash
        if test ! -d $git_dir
            or ! repo_healthy $git_dir
            printf "Git source not ready\n"
            return 1
        end
        set --append git_hashes $git_hash
    end
    if ! scripts/deploy_git_sources.bash $argv[1] $git_hashes
        printf "Failed to deploy git sources\n"
        return 1
    end
end

function ensure_cache_file # 1: path, 2: url, 3: cksum executable, 4: checksum
    if test -f $argv[1]
        return 0
    end
    set file_work $argv[1].work
    switch $argv[2]
    case 'file://*'
        set cmd /usr/bin/curl -qgC - -o $file_work $argv[2]
    case 'ftp://*'
        set cmd /usr/bin/curl -qgfC - --ftp-pasv --retry 3 --retry-delay 3 -o $file_work $argv[2]
    case 'http'{,s}'://*'
        set cmd /usr/bin/curl -qgb "" -fLC - --retry 3 --retry-delay 3 -o $file_work $argv[2]
    case 'rsync://*'
        set cmd /usr/bin/rsync --no-motd -z $argv[2] $file_work
    case 'scp://*'
        set cmd /usr/bin/scp -C $argv[2] $file_work
    case '*'
        set cmd /usr/bin/curl -o $file_work $argv[2]
    end
    set try 0
    rm -f $file_work
    while test $try -lt 3
        set try (math $try + 1)
        printf "Caching '%s' <= '%s'...\n" $file_work $argv[2]
        if ! $cmd
            rm -f $file_work
            continue
        end
        if test "$($argv[3] $file_work | string split --fields 1 ' ')" = "$argv[4]"
            mv $file_work $argv[1]
            break
        else
            printf "File '%s' from '%s' is corrupted\n" $argv[1..2]
            rm -f $file_work
        end
    end
    if test ! -f $argv[1]
        printf "Failed to download from '%s' after all tries\n" $argv[2]
        return 1
    end
end

function deploy_file_sources # 1: pkgname
    set pkgbuild build/$argv[1]/PKGBUILD
    if ! set files (scripts/get_file_sources.bash $pkgbuild)
        printf "Failed to parse file sources from '%s'\n" $argv[1]
        return 1
    end
    if test (count $files) -lt 2
        return 0
    end
    switch $files[1]
    case ''
        printf "Warning: package '%s' does not have integrity check array for sources, cannot deploy\n" \
            $argv[1]
        return 0
    case {ck,md5,sha{1,224,256,384,512},b2} # Valid, do nothing
        set integ $files[1]
    case '*'
        printf "Invalid integrity %s\n" $files[1]
        return 1
    end
    for file in $files[2..]
        set file_cksum_url (string split --max 1 ' ' $file)
        if ! ensure_cache_file \
            sources/file-$integ/$file_cksum_url[1] \
                $file_cksum_url[2] {$integ}sum $file_cksum_url[1]
            printf "Failed to ensure cache file %s: '%s'\n" \
                $integ $file
            return 1
        end
    end
    if ! scripts/deploy_file_sources.bash $argv[1]
        printf "Failed to deploy file sources\n"
        return 1
    end
end

function deploy_sources # 1: pkgname 2: pkg git hash
    rm -rf build/$argv[1]
    mkdir build/$argv[1]
    if ! git --git-dir sources/git/$argv[2] --work-tree build/$argv[1] checkout -f master
        printf "Failed to checkout package '%s' to builddir\n" $argv[1]
        return 1
    end
    if ! deploy_git_sources $argv[1]
        printf "Failed to deploy git sources for package '%s'\n" $argv[1]
        return 1
    end
    if ! deploy_file_sources $argv[1]
        printf "Failed to deploy file sources for package '%s'\n" $argv[1]
        return 1
    end
    if ! scripts/extract_sources.bash $argv[1]
        printf "Failed to prepare non-git non-file sources for package '%s'\n" $argv[1]
        return 1
    end
end

function deploy_if_need_build # 1: pkgname, 2: pkg git repo hash,
    if ! set commit "$(git --git-dir sources/git/$argv[2] rev-parse master)"
        printf "Failed to get latest commit ID from pkg '%s'\n" $argv[1]
        return 1
    end
    set pkgbuild "$(mktemp)"
    if ! dump_pkgbuild sources/git/$argv[2] $pkgbuild
        printf "Failed to get PKGBUILD from '%s' to parse vcs sources\n" \
                $argv[1]
        return 1
    end
    set source_deployed 0
    if test "$(scripts/type_var.bash $pkgbuild pkgver)" = 'function'
        printf "Package '%s' has a pkgver() function, need a full checkout to run it\n" $argv[1]
        if ! deploy_sources $argv[1] $argv[2]
            printf "Failed to deploy sources for package '%s'\n" $argv[1]
            return 1
        end
        set source_deployed 1
        if ! set pkgver "$(scripts/get_pkgver.bash $argv[1])"
            printf "Failed to run pkgver() for package '%s'\n" $argv[1]
            return 1
        end
        # Get pkgver here
        set build "$argv[1]-$commit-$pkgver"
    else
        set build $argv[1]-$commit
    end
    echo "$build" > build/$argv[1].id
    rm -f $pkgbuild
    printf "Build ID for package '%s' is '%s'\n" \
        $argv[1] $build
    set --append builds $build
    if test -d pkgs/$build -a (count pkgs/$build/*) -gt 0
        printf "Package '%s' with current build ID '%s' already built, skipping it\n" \
            $argv[1] $build
        rm -rf build/$argv[1]
        return 255
    end
    if test $source_deployed -eq 0
        and ! deploy_sources $argv[1] $argv[2]
        printf "Failed to deploy sources for package '%s'\n" $argv[1]
        return 1
    end
    return 0
end

function prepare_sources
    if ! prepare_git_sources
        echo "Failed to prepare git sources"
        return 1
    end
    set --global builds
    for i in (seq 1 $pkg_cnt)
        set hash $hashes[$i]
        set pkg $pkgs[$i]
        deploy_if_need_build "$pkg" "$hash"
        switch $status
        case 0  # need build, do nothing
        case 1
            printf "Failed to deploy sources for package '%s' that needs building\n" \
                $pkg
            return 1
        case 255 # Already built, skip
            continue
        end
    end
end

function makepkg_to_pkgs
    for pkg in build/*
        if test -d $pkg
            while test (string split --fields 1 ' ' (cat /proc/loadavg)) -ge $load_max
                # Wait for CPU resource
                sleep 1
            end
            printf "Started building work for '%s'\n" $pkg
            scripts/makepkg_to_pkgs.bash $pkg &
        end
    end
    wait
end

function link_pkgs
    for build in $builds
        for pkg in pkgs/$build/*.pkg.tar
            ln -sf ../$build/$(basename $pkg) pkgs/latest/
        end
    end
end

# Parse arguments
set config
begin
    argparse 'g/git-proxy=' 'H/holdver' 'l/load-max=' -- $argv
    set git_proxy $_flag_g
    if test -n "$_flag_l"
        set load_max $_flag_l
    end
    if test -n "$_flag_H"
        set holdver 1
    end
    set config $argv[1]
end

# Config must be set
if test -z $config
    echo "Config file not set"
    exit 1
end 
if ! test -f $config
    printf "Config file '%s' does not exist\n" $config
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
if ! read_pkgbuilds $config
    echo "Failed to read PKGBUILDs"
    exit 1
end

sync_pkgbuilds

if ! prepare_sources
    echo "Failed to prepare sources"
    exit 1
end

if ! makepkg_to_pkgs
    echo "Failed to makepkgs"
    exit 1
end

if ! link_pkgs
    echo "Failed to linking packages"
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