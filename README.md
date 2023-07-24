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
