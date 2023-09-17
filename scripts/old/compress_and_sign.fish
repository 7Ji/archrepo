# set repo $argv[1]
set repo 7Ji
set arch aarch64


echo "=> Integrity check for existing repo"
set temp_dir (mktemp -d)
tar -C $temp_dir -xf $repo.db
set old_pkg_files (sed -n '/%FILENAME%/{n;p;}' $temp_dir/*/desc)
set old_pkg_names (sed -n '/%NAME%/{n;p;}' $temp_dir/*/desc)
set old_pkg_count (count $old_pkg_files)
if test $old_pkg_count -ne (count $old_pkg_names)
    echo "Error: pkg count mismatch"
    exit 1
end
for i in (seq 1 $old_pkg_count)
    set old_pkg_name $old_pkg_names[$i]
    set old_pkg_file $old_pkg_files[$i]
    if test ! -f $old_pkg_file
        printf "Error: Pkgfile '%s' missing for old package '%s'" $old_pkg_file $old_pkg_name
    end
    if test ! -f $old_pkg_file.sig
        printf "Error: Sig missing for pkgfile '%s' for old package '%s'" $old_pkg_file $old_pkg_name
    end
    printf "[%s] %s OK\n" $old_pkg_name $old_pkg_file
end
rm -rf $temp_dir
echo "=> Integrity check passed for existing repo"

echo "=> Scanning new packages..."
set new_pkg_files_raw *.pkg.tar
if ! set new_pkg_count (count $new_pkg_files_raw)
    or test $new_pkg_count -eq 0
    echo "No new packages"
    exit 0
end
set new_pkg_files_added (string replace -- ':' '.' $new_pkg_files_raw.zst)
set new_pkg_names
set new_pkg_files_original
set new_pkg_files_compressed
set old_pkg_files_remove
echo "=> Checking if package needs compressing or signing..."
for i in (seq 1 $new_pkg_count)
    set new_pkg_file_original $new_pkg_files_raw[$i]
    set new_pkg_file_compressed $new_pkg_files_added[$i]
    if test -f $new_pkg_file_compressed
        if test -f $new_pkg_file_compressed.sig
            printf "Skipped existing %s\n" $new_pkg_file_compressed
            continue
        else
            printf "Warning: pkgfile existing but sig not found for %s, would re-create the pkg\n" $new_pkg_file_compressed
            rm -f $new_pkg_file_compressed
        end
    end
    if ! set new_pkg_name (tar -xOf $new_pkg_file_original .PKGINFO | sed -n 's/^pkgname = \(.\+\)$/\1/p')
        printf "Failed to get pkg name for pkg file '%s'" $new_pkg_file_original
        exit 1
    end
    set --append new_pkg_files_original $new_pkg_file_original
    set --append new_pkg_files_compressed $new_pkg_file_compressed
    set --append new_pkg_names $new_pkg_name
    for i in (seq 1 $old_pkg_count)
        set old_pkg_name $old_pkg_names[$i]
        if test $old_pkg_name = $new_pkg_name
            set --append old_pkg_files_remove $old_pkg_files[$i]
            break
        end
    end
end
if ! set new_pkg_count (count $new_pkg_names)
    or test $new_pkg_count -eq 0
    echo "No new packages need to be compressed"
else
    echo "=> Compressing new packages..."
    set compress_ongoing 0
    for i in (seq 1 $new_pkg_count)
        if test $compress_ongoing -eq 4
            set compress_ongoing 0
            while test (cat /proc/loadavg | string split --fields 1 ' ') -gt 8
                sleep 3
            end
        else
            set compress_ongoing (math "$compress_ongoing + 1")
        end
        printf "[%s] %s <- %s\n" $new_pkg_names[$i] $new_pkg_files_compressed[$i] $new_pkg_files_original[$i]
        zstd -22 --ultra --force -o $new_pkg_files_compressed[$i] $new_pkg_files_original[$i] &
    end
    echo "Waiting for all compression jobs..."
    wait
    read --prompt-str "> Ready for signing, press Enter to continue"
    rm -f $new_pkg_file_compressed.sig
    for new_pkg_file_compressed in $new_pkg_files_compressed
        gpg --use-agent --detach-sign --output $new_pkg_file_compressed{.sig,}
    end
end

echo "=> Adding new packages..."
echo "New package files need to be added: $new_pkg_files_added"
echo "Old package files need to be removed: $old_pkg_files_remove"

echo "--------------------------------"
echo repo-add --verify --sign $repo.db.tar.zst $new_pkg_files_added
for file in $old_pkg_files_remove{,.sig} $repo.{db,files}{,.sig}
    echo gh release delete-asset $arch --yes $file
end
echo gh release upload $arch $new_pkg_files_added{,.sig} $repo.{db,files}{,.sig}
echo rm -f $old_pkg_files_remove{,.sig} $new_pkg_files_raw
echo "--------------------------------"
read --prompt-str "> Ready for accessing Github API, press Enter to continue, or exit and run manually the above commands"

repo-add --verify --sign $repo.db.tar.zst $new_pkg_files_added
for file in $old_pkg_files_remove{,.sig} $repo.{db,files}{,.sig}
    gh release delete-asset $arch --yes $file
end
gh release upload $arch $new_pkg_files_added{,.sig} $repo.{db,files}{,.sig}
rm -f $old_pkg_files_remove{,.sig} $new_pkg_files_raw