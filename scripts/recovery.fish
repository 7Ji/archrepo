cd pkgs
rm -rf latest updated
mkdir latest updated
for i in *
    switch $i
    case "updated" "latest"
    case '*'
        for j in $i/*
            set name (string split --right --max 1 --fields 2 '/' $j)
            if test -f latest/$name
                set newmtime (stat --dereference --format %Y latest/$name)
                set oldmtime (stat --dereference --format %Y $j)
                if test $newmtime -le $oldmtime
                    continue
                end
            end
            ln -sf ../$j latest/$name
        end
    end
end