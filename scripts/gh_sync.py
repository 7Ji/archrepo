# Sync local repo to github release, this should be run on the repo hoster, not on builders
# e.g. run this in /srv/http/repo/7Ji, in which there're aarch64 and x86_64 subfolders

import github
import requests
import base64
import hashlib
import os
import json

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
        files_remote = set()
        for asset in release.get_assets():
            files_remote.add(asset.name)
            path_local = f"{name}/{asset.name}"
            if not os.path.exists(path_local):
                print(f"Release asset {asset.name} does not exist locally, should delete")
                asset.delete_asset()
                continue
            try:
                sha256_remote = asset._rawData['digest'][7:]
            except (AttributeError, KeyError, TypeError):
                sha256_remote = None
            if sha256_remote:
                with open(path_local, 'rb') as f:
                    sha256_local = hashlib.file_digest(f, 'sha256').hexdigest()
                if sha256_remote == sha256_local:
                    print(f"Skipped file {path_local} with same sha256 as remote {sha256_remote}")
                    continue
                print(f"Replacing file {path_local}, remote sha256 {sha256_remote} != local sha256 {sha256_local}")
            else:
                print(f"Replacing file {path_local} with no remote sha256")
            asset.delete_asset()
            release.upload_asset(path = path_local)

        print(f"Assets before appending: {files_remote}")
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
