# Pacman repo for my pre-built AUR packages


import my signing key:
```
sudo pacman-key --recv-keys BA27F219383BB875
sudo pacman-key --lsign BA27F219383BB875
```

add the following session in your `/etc/pacman.conf`:

```
[7Ji]
Server = https://github.com/7Ji/archrepo/releases/download/$arch
```

## Building
The building script is available under `scripts` as `scripts/build.fish`, it is written with saving bandwidth usage yet keeping every package up-to-date in mind. 

To run the building script, you must have `fish` installed, and run it with `fish` in this folder, e.g.:
```
fish scripts/build.fish aarch64.yaml
```

The argument are as following:
 - `-g` / `--git-proxy` `[proxy]` define the proxy to use for git, it is only used after a failed connection without proxy
 - `-H` / `--holdver` keep all of PKGBUILDs version and .git sources held static 
 - `-l` / `--load-max` `[loadmax]` do not start new build job if 1-min load max is higher than this, default is 8.00, meaning full-load for a 8-CPU system

The building script runs differently from what you would imagine, in that:
 - All PKGBUILDs are maintained as bare .git repos in a dedicated folder `sources/git`, they're only checked out if building is needed or it needs to run `pkgver()`.
 - All git sources are also maintained as bare .git repos in a dediated folder `sources/git`, at the building stage only a symlink is passed to makepkg.
 - These two kinds of repos are stored under `sources/git` with a name calculated using 64-bit xx3hash with their URLs. Benifits: single layer, deduplication.
 - All non-local file sources with corresponding checksums are maintained under `sources/file-{ck,md5,sha{1,224,256,384,512},b2}`, at the building stage only a symlink is passed to makepkg
   - Can handle when upstream changed file, but kept the file name. We download before symlinking so links never point to wrong files
   - Can save a lot of bandwidth when multiple sources share the same checksum.
 - A build is triggered only when it has a unique build ID that's not built before, which is `[pkgname]-[commit hash](-[pkgver])`, in which `[pkgver]` is only for the pacakges that define their `pkgver()` functions
   - Can handle the case where `pkgver`, `pkgrel`, `epoch`, etc are the same yet the PKGBUILD silently changed. As commit hash would change
   - Can handle the case where VCS source updated, as `pkgver` would change
 - Packages are all stored under `pkgs/[build ID]`, with two dedicated folders `pkgs/latest` containing links of packages that're latest, and `pkgs/updated` containing packages that's updated. 
   - If the repo maintainer does full update, `pkgs/latest` would be useful.
   - If the repo maintainer only does partial update, `pkgs/updated` would be useful.
 - Specially, compressing and signing are left out, so the repo maintainer is freely to choose the way they want to compress and sign.

 For compressing and signing packages, another script `scripts/compress_and_sign.fish` is available, run it under either `pkgs/latest` or `pkgs/updated`, or your other folder that you copy pkgs from these two folders.

## Pacman sync change

If you already have the same packages intalled in other ways (e.g. from other repos, via `yay`, or lcoally via `pacman -U`), you'll need to manually "install" them again once, since `pacman` won't update packages to a different repo.

E.g., if you come from https://github.com/7Ji/orangepi5-archlinuxarm , then you need to run the following command once so pacman will know it can upgrade to kernel available at repo `7Ji` in the future:

```
pacman -Syu 7Ji/linux-aarch64-orangepi5{,-headers}
``````

E.g., if you come from https://github.com/7Ji/amlogic-s9xxx-archlinuxarm , then you need to run the following command once so pacman will know it can upgrade to kernel available at repo `7Ji` in the future:

```
pacman -Syu 7Ji/linux-aarch64-{7ji{,-headers},flippy{,-dtb-amlogic,-headers}}
``````

After running such command once, you can just `pacman -Syu` later to upgrade normally.
