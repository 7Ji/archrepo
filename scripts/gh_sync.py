# Sync local repo to github release, this should be run on the repo hoster, not on builders
# e.g. run this in /srv/http/repo/7Ji, in which there're aarch64 and x86_64 subfolders

import github
import requests
import base64
import hashlib
import os
import json

def is_intact(session: requests.Session, url, md5_local) -> bool:
    for i in range(6):
        try:
            response = session.get(url, stream = True, timeout = 5)
        except requests.exceptions.Timeout as e:
            print(f"Timeout accessing remote asset {url}, try {i + 1} of 6")
            response = None
        else:
            response.close()
            break
    if response is None:
        print(f"Timeout accessing remote asset {url} after all tries, assuming corrupted")
        return False
    if response.status_code != 200:
        print(f"Failed to access remote asset {url}, status code {response.status_code}, assuming corrupted")
        return False
    try:
        md5_remote = base64.b64decode(response.headers['content-md5'])
    except KeyError:
        print(f"Response header did not carry md5 of asset {url}, downloading full file")
        hasher = hashlib.new('md5')
        for chunk in response.iter_content(0x100000):
            hasher.update(chunk)
        md5_remote = hasher.digest()
    if md5_local != md5_remote:
        print(f"Release asset {url} desynced, MD5 mismatch: local {md5_local} != remote {md5_remote}")
        return False
    print(f"Release asset {url} is good")
    return True

class Hashes:
    def __init__(self, file):
        self.hashes = dict()
        try:
            with open(file, 'rb') as f:
                hashes = json.load(f)
                self.hashes = hashes
        except:
            pass

    def write(self, file):
        file_cache = f"{file}.cache"
        with open(file_cache, 'w') as f:
            json.dump(self.hashes, f)
        os.replace(file_cache, file)

    def get(self, path):
        return self.hashes.get(path)

    def update(self, path, hash):
        self.hashes[path] = hash


class GithubAPI:
    def __init__(self, token):
        self._token = token

    def __enter__(self):
        self._api = github.Github(auth=github.Auth.Token(self._token))
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self._api.close()
    
    def get_repo(self, repo: str):
        return self._api.get_user().get_repo(repo)

    def sync_release(self, repo: github.Repository, name: str, hashes: Hashes):
        release = repo.get_release(name)
        session = requests.Session()
        files_remote = []
        for asset in release.get_assets():
            files_remote.append(asset.name)
            path_local = f"{name}/{asset.name}"
            if not os.path.exists(path_local):
                print(f"Release asset {asset.name} does not exist locally, should delete")
                asset.delete_asset()
                continue
            with open(path_local, 'rb') as f:
                hasher = hashlib.file_digest(f, 'md5')
            md5_last_hex = hashes.get(path_local)
            md5_local_bytes = hasher.digest()
            md5_local_hex = hasher.hexdigest()
            if md5_last_hex == md5_local_hex or is_intact(session, asset.browser_download_url, md5_local_bytes):
                continue
            print(f"Replacing file {path_local}")
            asset.delete_asset()
            release.upload_asset(path = path_local)
            hashes.update(path_local, md5_local_hex)
        
        with os.scandir(name) as it:
            for entry in it:
                if not entry.name.startswith('.') and entry.is_file():
                    if not entry.name in files_remote:
                        path_local = f"{name}/{entry.name}"
                        print(f"Appending file {path_local}")
                        release.upload_asset(path = path_local)

if __name__ == '__main__':
    with open('token', 'r') as f:
        token = f.read()
    hashes = Hashes('hashes')
    with GithubAPI(token) as api:
        repo = api.get_repo('archrepo')
        api.sync_release(repo, 'aarch64', hashes)
        api.sync_release(repo, 'x86_64', hashes)
    hashes.write('hashes')