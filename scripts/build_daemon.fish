# #1: arch
switch (git remote get-url origin)
case git://git.lan/repo{.git,}
    echo "Local builder daemon started"
case https://github.com/7Ji/archrepo{.git,}
    echo "Distributed builder daemon started"
case '*'
    echo "Remote origin URL not in whitelist, cowardly refuse to build to avoid damaging work space"
    exit 1
end

set arch aarch64
argparse 'a/arch=' -- $argv
if test -n $_flag_a
    set arch $_flag_a
end

function warn
    echo "WARN: $argv"
end

function error
    echo "ERROR: $argv"
    exit 1
end

set hash_self (sha256sum (status -f) | string split ' ' -f 1)
set idle 8000

while true
    set remote_commit (git ls-remote origin master | string split '	' -f 1) || error 'Failed to get remote master commit'
    set local_commit (git rev-parse master) || error 'Failed to get local master commit'
    if test $remote_commit = $local_commit
        set idle (math "$idle + 1")
        if test $idle -lt 8000 # 1 day = 86400 seconds = 8640 idle loops
            sleep 10
            continue
        else # Force a build if already waited for almost a day
            set idle 0
        end
    else
        echo "Updating '$local_commit' -> '$remote_commit'"
        git fetch origin '+refs/heads/master:refs/remotes/origin/master' || error 'Failed to fetch from origin'
        git reset --hard origin/master || error 'Failed to reset to origin/master'
        if test (sha256sum (status -f) | string split ' ' -f 1) != $hash_self
            warn 'Daemon script itself updated, exit to let the outer supervisor decide whether to continue'
            exit 0
        end
        set idle 0
    end
    sudo ./arch_repo_builder --noclean $arch.yaml || warn 'Failed to build'
    if test (count pkgs/updated/*) -gt 0
        fish scripts/partial_update.fish $arch || error 'Failed to update and refuse to continue as there are pkgs to upload'
        set idle 8000 # Force an immediate rebuild regardless, to possibly rebuild those depending on built packages
    else
        fish scripts/partial_update.fish $arch || warn 'Failed to update'
    end
end