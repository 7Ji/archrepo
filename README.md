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

## Package list
Check [aarch64.yaml](aarch64.yaml) and [x86_64.yaml](x86_64.yaml), the `pkgbuilds` section declares the lists. The URLs follows the alias rule documented [here](https://github.com/7Ji/arch_repo_builder#config).

Note that, different from most of the existing repos, I don't maintain the repo config alongside the packages. But most of them are available either on AUR, or under [7Ji-PKGBUILDs organisation](https://github.com/7Ji-PKGBUILDs).


## Submitting new package
Please note all of the packages for aarch64 need to be built on my own Orange Pi 5 Plus + Orange Pi 5 combo, I run all my projects without sponsorship including this one. The current daily partialy update + weekly full update model is already very time-consuming and power-hungry. So **I don't want to accept packages that's not absolutely needed**. 

Packages meeting the following conditions **won't be accepted**:
  - Already maintained in a repo, especially already maintained in a distro's official repo
  - Not verified to work on actual hardware
  - Take too much time to build

Submit the package by modifying `aarch64.yaml` and adding your package in the pkgbuilds list, at the correct alphabetical position, then open a PR. If you could provide the time needed to build it then it would be better.