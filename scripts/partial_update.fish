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
popd # pkgs/updated
set files $pkgs $sigs
pushd releases
for file in $files
    ln -sf ../../pkgs/latest/$file github/(string replace ':' '.' $file)
    ln -sf ../../pkgs/latest/$file local/$file
end
pushd github
repo-add --verify --sign 7Ji.db.tar.zst (string replace ':' '.' $pkgs) &
for file in *.pkg.tar*
    if test ! -f $file
        rm -f $file
    end
end
popd # github
pushd local
repo-add --verify --sign localrepo.db.tar.zst $pkgs &
for file in *.pkg.tar*
    if test ! -f $file
        rm -f $file
        gh release delete-asset $arch $file --yes
    end
end
popd # local
wait
sudo rsync --recursive --verbose --copy-links --delete local/ /srv/http/localrepo/$arch &
pushd github
set temp_assets (mktemp)
gh release view $arch | sed -n 's/^asset:	\(.\+\)$/\1/p' > $temp_assets
set gh_files (string replace ':' '.' $files)
set --append gh_files 7Ji.{db,files}{,.sig}
for file in $gh_files
    if grep "^$file\$" $temp_assets
        gh release delete-asset $arch $file --yes
    end
end
rm -f $temp_assets
gh release upload $arch $gh_files
popd # github
popd # releases
