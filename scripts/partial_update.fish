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
repo-add --verify --sign 7Ji.db.tar.zst (string replace ':' '.' $pkgs) &
for file in *.pkg.tar*
    if test ! -f $file
        rm -f $file
        gh release delete-asset $arch $file --yes
    end
end
wait
rsync --recursive --verbose --copy-links --delete ./ /srv/http/repo/7Ji/$arch &
set temp_assets (mktemp)
gh release view $arch | sed -n 's/^asset:	\(.\+\)$/\1/p' > $temp_assets
set gh_files (string split --right --max 1 --fields 2 '/' $files | string replace ':' '.')
set --append gh_files 7Ji.{db,files}{,.sig}
for file in $gh_files
    if grep "^$file\$" $temp_assets
        gh release delete-asset $arch $file --yes
    end
end
rm -f $temp_assets
for file in $gh_files
    set try 0
    while test $try -lt 3
        set try (math $try + 1)
        if gh release upload $arch $file
            echo "Uploaded $file to Github release $arch"
            set try 0
            break
        else
            echo "Failed to upload $file, try $try of 3"
        end
    end
    if test try -lt 0
        echo "Failed to upload $file after all 3 tries, maintainer attention needed"
        echo "[$(date)] Partial update failed: $file" >> logs/update.log
    end
end
popd # releases
# Update the release note
set full_note (gh release view $arch --json body | sed -n 's/.\+"\(Last full update at .\+\)".\+/\1/p' | string split --max 1 --fields 1 '\\')
if test -n "$full_note"
    gh release edit $arch --notes "$full_note
    
Last partial update at $(date)"
end
