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

# What this really checks is the detached HEAD status, which is found on either:
# 1. Broken repo, where HEAD cannot be peeled into valid commit due to the
#    symref it points to is no more valid
# 2. New repo, where our init master branch does not have any commit
function repo_healthy
    if test "$(git --git-dir $argv[1] rev-parse HEAD)" = 'HEAD'
        return 1
    else
        return 0
    end
end

# This update the git repo with a mirror fetch + prune, then update HEAD
# Note that due to limit of git command-line, we can't get the remote HEAD
# in the same step as updating. This could be improved by rewriting the logic
# into a single .c binary that uses libgit2, if efficiency is important.
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

# Sync local git repo to remote. Init if not found, then update
function sync_repo # 1: dir, 2: url. 3: whether to update HEAD. 
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

# This is ugly as the function does not actually know the YAML format.
# There will certainly be bad YAML config that breaks the function.
# But as we maintain the PKGBUILDs list in-house, we can ignore the problem.
# This could be rewritten using language that knows YAML format.
function read_pkgbuilds # 1: config
    set list (grep -o '^ - [a-Z0-9_-]\+: [a-Z0-9_:/.-]\+'  $argv[1])
    set --global pkgs (string replace : '' (string split --no-empty --fields 2 ' ' $list))
    set --global urls (string split --no-empty --fields 3 ' ' $list)
    set --global hashes (for url in $urls; xxh3sum_64bit $url; end)
    set --global pkg_cnt (count $pkgs)
    if test $pkg_cnt -eq 0
        echo "No packages defined"
        return 1
    end
end

# Someone might want to change this to multi-threaded, DON'T DO THAT!
# Most of our PKGBUILDs are from AUR, and as AUR runs completely profit-free,
# I don't want to put too much load on the server.
function sync_pkgbuilds
    for i in (seq 1 $pkg_cnt)
        printf "Syncing PKGBUILD '%s' with URL '%s', hash '%s'\n" $pkgs[$i] $urls[$i] $hashes[$i]
        if ! sync_repo sources/git/$hashes[$i] $urls[$i] no
            printf "Failed to sync PKGBUILD '%s'\n" $pkgs[$i]
            return 1
        end
    end
end

# Hoo, surprised? We don't need to check out the whole repo to get PKGBUILD
function dump_pkgbuild # 1: git dir 2: output
    if ! git --git-dir $argv[1] cat-file blob master:PKGBUILD > $argv[2]
        printf "Failed to dump PKGBUILD from '%s' to '%s'\n" $argv[1] $argv[2]
        return 1
    end
end

# Dumps all PKGBUILDs, parse them and get a list of git sources, sync them
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

# Deploy (symlink) git sources into a package's build folder
# The package should NOT write nor update it, as we've updated the repo, and
# writes to the symlink are actually writing to our dedicated git sources 
# storage.
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

# Cache a network file that has checksum. Files will be downloaded as
# sources/file-{integrity algorithm}/{checksum} if they're not found.
# NOTE: The integrity check is only performed once when they're downloaded,
# and is skipped in future for performance. Do not write to the files after 
# they're cached. 
function cache_file # 1: path, 2: url, 3: cksum executable, 4: checksum
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

# Deploy (symlink) network file sources into a package's build folder
# The package should NOT write to it, as writes to the symlink are actually 
# writing to our dedicated network file sources storage, and corrupting the
# storage.
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
        if ! cache_file \
            sources/file-$integ/$file_cksum_url[1] \
                $file_cksum_url[2] {$integ}sum $file_cksum_url[1]
            printf "Failed to cache file %s: '%s'\n" \
                $integ $file
            return 1
        end
    end
    if ! scripts/deploy_file_sources.bash $argv[1]
        printf "Failed to deploy file sources\n"
        return 1
    end
end

# Deploy (symlink) git and network file sources into a package's build folder
# Then use libmakepkg to download remaining sources
# Then extract the sources
# After this logic, $srcdir is complete, and running pkgver() is possible.
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

# Check if a package needs building, and deploy the sources so we can later run
# `makepkg --noextract` directly if the package needs building.
#
# The check is actually performed against a build ID constructed as:
#   [package name]-[package commit](-[pkgver])
#
# If the PKGBUILD does not define pkgver(), then the check is fast, and deploy-
# ment can be totally skipped.
# If it defines pkgver(), then a temporary yet full deployment is always needed,
# so it would always be slow. The temporary deployed package would be removed if 
# it does not need building.
#
# The result is binary: either the package needs building and build/$pkg
# is created with all of needed source needed, as if after `makepkg --nobuild`;
# or the package does not need building and builg/$pkg does not exist after
# the checking.
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
    rm -rf pkgs/$build
    echo "$build" > build/$argv[1].id
    return 0
end

# Prepare sources so we can later run `makepkg --noextract` on all packages that
# need building.
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

# Make all packages and move them to folders corresponding to their build IDs,
# and link the packages to pkgs/updated.
# The step moving the packages is atomic, so the pkg/[build ID] folder would
# always contain all packages. This is important for subsequent runs as they
# can trust such robustness.
function makepkg_to_pkgs
    set i 0
    for pkg in build/*
        if test -d $pkg
            set i (math $i + 1)
            # Force a sleep per 4 packages, or when under heavy load
            if test (math $i % 4) -eq 0
                or test (string split --fields 1 ' ' (cat /proc/loadavg)) -gt $load_max
                sleep 10
                while test (string split --fields 1 ' ' (cat /proc/loadavg)) -gt $load_max
                    # Wait for CPU resource
                    sleep 3
                end
            end
            printf "Started building work for '%s'\n" $pkg
            scripts/makepkg_to_pkgs.bash $pkg &
        end
    end
    wait
end

# Create links under pkgs/latest, so all latest packages can be found
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

if ! sync_pkgbuilds
    echo "Failed to sync PKGBUILDs"
    exit 1
end

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