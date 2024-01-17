# Sync local repo to github release, this should be run on the repo hoster, not on builders
# e.g. run this in /srv/http/repo/7Ji, in which there're aarch64 and x86_64 subfolders

import github
import requests
import base64
import hashlib
import os

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

    def sync_release(self, repo: github.Repository, name: str):
        release = repo.get_release(name)
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
            md5_local = hasher.digest()
            response = requests.get(asset.browser_download_url, stream = True)
            if response.status_code != 200:
                print(f"Failed to access remote asset {asset.name}, assuming corrupted")
                asset.delete_asset()
            else:
                md5_remote = base64.b64decode(response.headers['content-md5'])
                if md5_local == md5_remote:
                    print(f"Release asset {asset.name} is good")
                    continue
                else:
                    print(f"Release asset desynced, MD5 mismatch: local {md5_local} != remote {md5_remote}")
                    asset.delete_asset()
            print(f"Replacing file {path_local}")
            release.upload_asset(path = path_local)
        
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
    with GithubAPI(token) as api:
        repo = api.get_repo('archrepo')
        api.sync_release(repo, 'aarch64')
        api.sync_release(repo, 'x86_64')