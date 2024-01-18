# Update packages on demand, re-create the DB and the release
# #1: arch
if test -z "$argv[1]"
    set arch aarch64
else
    set arch $argv[1]
end
pushd pkgs/updated
set pkgs *.pkg.tar.zst
set sigs *.pkg.tar.zst.sig
if test (count $pkgs) -eq 0
    exit 0
end
if test (count $pkgs) -ne (count $sigs)
    exit 1
end
set files (readlink $pkgs $sigs)
popd # pkgs/updated
pushd releases
for file in $files
    ln -sf (string replace '../' '../pkgs/' $file) (string split --right --max 1 --fields 2 '/' $file | string replace ':' '.')
end
repo-add --verify --sign 7Ji.db.tar.zst (string replace ':' '.' $pkgs)
for file in *.pkg.tar*
    if test ! -f $file
        rm -f $file
    end
end
fish ../scripts/remove_old.fish
rsync --recursive --verbose --copy-links --delete ./ /srv/http/repo/7Ji/$arch
popd # releases
