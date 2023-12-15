import argparse
import hashlib
import subprocess
import sys
import time

def check_git_url():
    r = subprocess.run(
        ("git", "remote", "get-url", "origin"), 
        stdout=subprocess.PIPE)
    if r.returncode != 0 or \
        not (r.stdout == b'git://git.lan/repo.git\n' or \
            r.stdout == b'https://github.com/Vexiona/archrepo.git\n'):
        print("Remote origin URL not in whitelist or cannot get it, cowardly refuse to build")
        exit(1)

def parse_arg() -> (str, str, list[str]):
    parser = argparse.ArgumentParser(prog='build daemon')
    parser.add_argument('--arch', default="aarch64")
    (args_known, args_remaining) = parser.parse_known_args()
    return (args_known.arch, sys.argv[0], args_remaining)

def sha256_file(path: str) -> bytes:
    handle = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            buffer = f.read(0x10000)
            if not buffer:
                break
            handle.update(buffer)
    return handle.digest()

def get_remote_commit() -> bytes:
    r = subprocess.run(
        ("git", "ls-remote", "origin", "master"), 
        stdout=subprocess.PIPE)
    if r.returncode != 0:
        print("Failed to get remote commit")
        exit(1)
    return r.stdout[0:40]

def get_local_commit() -> bytes:
    r = subprocess.run(
        ("git", "rev-parse", "master"), 
        stdout=subprocess.PIPE)
    if r.returncode != 0:
        print("Failed to get remote commit")
        exit(1)
    return r.stdout[0:40]

def update_git_repo():
    r = subprocess.run(('git', 'fetch', 'origin', '+refs/heads/master:refs/remotes/origin/master'))
    if r.returncode != 0:
        print("Failed to fetch update")
        exit(1)
    r = subprocess.run(('git', 'reset', '--hard', 'origin/master'))
    if r.returncode != 0:
        print("Failed to reset branch to update")
        exit(1)

def pkgs_update_non_empty() -> bool:
    try:
        with os.scandir("pkgs/updates") as it:
            if any(it):
                return True
    except:
        pass
    return False


def main():
    check_git_url()
    (arch, arg0, args_remaining) = parse_arg()
    arch_repo_builder_command = (
        'sudo', './arch_repo_builder', f'{arch}.yaml', '--noclean', *args_remaining)
    partial_update_command = (
        'fish', 'scripts/partial_update.fish', arch)
    del arch, args_remaining
    sha256_self = sha256_file(arg0)
    idle = 60
    while True:
        remote_commit = get_remote_commit()
        local_commit = get_local_commit()
        if remote_commit == local_commit:
            idle += 1
            if idle < 60:
                time.sleep(60)
                continue
            else: # Force a build if already waited for more than an hour
                idle = 0
        else:
            print(f"Updating '{local_commit}' -> '{remote_commit}'")
            update_git_repo()
            if sha256_file(arg0) != sha256_self:
                print("Daemon script updated, exit to let the outer supervisor decide whether to continue")
                exit(0)
            idle = 0
        subprocess.run(arch_repo_builder_command) # Don't care return
        r = subprocess.run(partial_update_command)
        if pkgs_update_non_empty():
            if r.returncode != 0:
                print('Failed to update and refuse to continue as there are pkgs to upload')
                exit(1)
            idle = 60

if __name__ == '__main__':
    main()
