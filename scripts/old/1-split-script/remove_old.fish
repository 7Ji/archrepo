# Try to remove files not in repo list, run in releases/
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