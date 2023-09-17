# Clean up the repo, re-create the DB and the release
pushd pkgs/latest
set files *
popd # pkgs/latest
rm -rf releases
mkdir releases/{,github,local}
pushd releases
for file in $files
    ln -s ../../pkgs/latest/$file github/(string replace ':' '.' $file)
    ln -s ../../pkgs/latest/$file local/$file
end
pushd github
repo-add --verify --sign 7Ji.db.tar.zst *.pkg.tar.zst &
popd # github
pushd local
repo-add --verify --sign localrepo.db.tar.zst *.pkg.tar.zst &
popd # local
wait # repo-add
sudo rsync --recursive --verbose --copy-links --delete local/ /srv/http/localrepo/aarch64 &
pushd github
gh release delete --yes aarch64
gh release create aarch64 --notes '' --latest 7Ji.{db,files}{,.sig} *.pkg.tar.zst{,.sig}
popd # github
popd # releases
wait # rsync