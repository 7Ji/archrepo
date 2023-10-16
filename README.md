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
To build, use https://github.com/7Ji/arch_repo_builder

To full update:
```
fish scripts/full_update.fish aarch64
```
To partial update:
```
fish scripts/partial_update.fish aarch64
```

## Submitting new package
Please note all of the packages for aarch64 need to be built on my own Orange Pi 5 Plus + Orange Pi 5 combo, I run all my projects without sponsorship including this one. The current daily partialy update + weekly full update model is already very time-consuming and power-hungry. So **I don't want to accept packages that's not absolutely needed**. 

Packages meeting the following conditions **won't be accepted**:
  - Already maintained in a repo, especially already maintained in a distro's official repo
  - Not available on AUR
  - Not verified to work on actual hardware
  - Take too much time to build

Submit the package by modifying `aarch64.yaml` and adding your package in the pkgbuilds list, at the correct alphabetical position, then open a PR. If you could provide the time needed to build it then it would be better.

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
