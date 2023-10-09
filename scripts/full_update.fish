# Clean up the repo, re-create the DB and the release
# #1: arch
if test -z "$argv[1]"
    set arch aarch64
else
    set arch $argv[1]
end
pushd pkgs/latest
set files *
popd # pkgs/latest
rm -rf releases
mkdir releases/{,github,local}
pushd releases
for file in $files
    set file_actual (readlink -f ../pkgs/latest/$file)
    ln -s $file_actual github/(string replace ':' '.' $file)
    ln -s $file_actual local/$file
end
pushd github
repo-add --verify --sign 7Ji.db.tar.zst *.pkg.tar.zst &
popd # github
pushd local
repo-add --verify --sign localrepo.db.tar.zst *.pkg.tar.zst &
popd # local
wait # repo-add
sudo rsync --recursive --verbose --copy-links --delete local/ /srv/http/localrepo/$arch &
pushd github
gh release delete --yes $arch
gh release create $arch --title $arch --notes "Last full update at $(date)" --latest 7Ji.{db,files}{,.sig} *.pkg.tar.zst{,.sig}
popd # github
popd # releases
wait # rsync