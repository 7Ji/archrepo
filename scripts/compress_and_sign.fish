set raw_pkgs *.pkg.tar
set cnt_pkgs (count $raw_pkgs)
if test $cnt_pkgs -eq 0
    echo "No pacakges need to be compressed nor signed"
    exit 0
end
# As Github would escape : to .
set com_pkgs (string replace -- ':' '.' $raw_pkgs.zst)
echo "Compressing pacakges..."
for i in (seq 1 $cnt_pkgs)
    set raw_pkg "$raw_pkgs[$i]"
    set com_pkg "$com_pkgs[$i]"
    printf "'%s' -> '%s'\n" "$raw_pkg" "$com_pkg"
    zstd -22T0 --ultra --rm -o "$com_pkg" "$raw_pkg" &
end
echo "Waiting for all compression jobs..."
wait
echo "Compression done, signing pacakges..."
rm -rf updates
mkdir updates
for com_pkg in $com_pkgs
    gpg --use-agent --detach-sign --output $com_pkg{.sig,}
    ln -s ../$com_pkg updates/$com_pkg
    ln -s ../$com_pkg.sig updates/$com_pkg.sig
end
echo "Generating and signing DB..."
repo-add --verify --sign 7Ji.db.tar.zst $com_pkgs
for db in 7Ji.{db,files}{,.sig}
    ln -s ../$db updates/$db
end