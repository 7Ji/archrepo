# Clean up the repo, re-create the DB and the release
# #1: arch
if test -z "$argv[1]"
    set arch aarch64
else
    set arch $argv[1]
end
pushd pkgs/latest
set files (readlink *)
popd # pkgs/latest
rm -rf releases
mkdir releases
pushd releases
for file in $files
    ln -sf (string replace '../' '../pkgs/' $file) (string split --right --max 1 --fields 2 '/' $file | string replace ':' '.')
end
repo-add --verify --sign 7Ji.db.tar.zst *.pkg.tar.zst
# Try to remove files not in repo list
set db (mktemp -d)
tar -xvf 7Ji.db -C $db
set list (mktemp)
sed -n '/%FILENAME%/{n;p;}' $db/*/desc | sort | uniq > $list
rm -rf $db
for pkg in *.pkg.tar.zst
    if ! grep -q "^$pkg\$" $list
        rm -f $pkg{,.sig}
    end
end
rm -f $list
rsync --archive --recursive --verbose --copy-links --delete ./ /srv/http/repo/7Ji/$arch &
gh release delete --yes $arch
gh release create $arch --title $arch --notes "Last full update at $(date)" --latest 7Ji.{db,files}{,.sig} *.pkg.tar.zst{,.sig}
popd # releases
wait # rsync
