# Pacman repo for my pre-built AUR-like packages
## Supported platforms
The repo is only for the following two platforms:
- **ArchLinux** x86_64
- **ArchLinux ARM** aarch64

Any derivative distros or other platforms are **neither tested, supported or intended**. If you encounter any issue on those platforms, don't report them. 

Special note for **ArchLinux ARM**: all of the kernel packages in this repo follows the **ArchLinux** (non-ARM) way of packing kernels, and all DTBs are stored under `/boot/dtbs/[package name]` so multiple kernels don't conflict with each other. They **do not** follow the ALARM way and downstream way which conflicts with each other, therefore:
- You can install multiple kernel packages from this repo for multi-booting
- You can install kernel packages alongside ALARM official kernels for multi-booting
- You **must** use a different booting configuration or adapt your existing ones to boot my kernel packages.

## Adding the repo
As every package in this repo is signed with my PGP key, including the keyring package itself, you must trust the repo before attempting to install any package. There're two ways of trusting the repo without tainting your trust chain: trust my key directly, or temporary disable the signkey verification and install the keyring package:

_Note: The packages are built against the dependencies from the official repos and this repo, and they're updated hourly, if you have other third party repos enabled, you'd better **place this repo prior to other third party repos** so you won't fetch wrong deps from their repos. The only exception is `archlinuxcn`, which I actively check for packaging conflicts_

### Direct trust
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
install my keyring (this automatically populates the keys, which should be a no-op as it was already added)
```
sudo pacman -Syu 7ji-keyring
```
### Temporary bypass
add the following session in your `/etc/pacman.conf`:
```
[7Ji]
SigLevel = Never
Server = https://github.com/7Ji/archrepo/releases/download/$arch
```
install my keyring
```
sudo pacman -Syu 7ji-keyring
```
remove the `SigLevel` line so the section now looks like this:
```
[7Ji]
Server = https://github.com/7Ji/archrepo/releases/download/$arch
```

## Installting the packages
Just install or update them by `pacman -Syu`

However, the builder would rebuild pacakges on every update of the PKGBUILD themselves, their sources, and their dependencies. This is all unattended and therefore the `pkgver` could be kept the same with the actual package already rebuilt and being a different binary release. This is a result of AUR-originated PKGBUILDs and that I don't want to introduce any difference from PKGBUILDs you would get from AUR directly.

In most cases you can just ignore the update without `pkgver` change and keep using your local one. But if your local one breaks with their dependencies updated from the official repo then you can just force a reinstall to update it to the one built against the latest dependency:
```
sudo pacman -Scc # Type y, enter, enter
sudo pacman -S [the broken package] 
```

## Building
It is not recommended to try to build these packages by yourself, as they take too much time. But if you want to, use https://github.com/7Ji/arch_repo_builder, which is a naive repo builder written in Rust for this repo which targets Github releases as repo storage, and build every package with clean dependency chain.

Note that the builder would build packages in a procedural way, i.e. it expects built dependencies to be pushed to the repo and used in the next run instead of the current one. So you'll find trouble in the sense of "bootstrapping" the repo. This should be fixed later but it's not on top of my to-do list. To work around this, disable packages that don't have all dependencies met first, then re-enable them as you get more and more of them into your repo.

## Package list
Check [aarch64.yaml](aarch64.yaml) and [x86_64.yaml](x86_64.yaml), the `pkgbuilds` section declares the lists. The URLs follows the alias rule documented [here](https://github.com/7Ji/arch_repo_builder#config).

Note that, different from most of the existing repos, I don't maintain the repo config alongside the packages. But most of them are available either on AUR, or under [7Ji-PKGBUILDs organisation](https://github.com/7Ji-PKGBUILDs).

## Build infrastructure
The `aarch64` packages are built on an Orange Pi 5 Plus (RK3588 + 16G + NVMe) with an Orange Pi 5 (RK3588S + 8G) as distcc volunteer.

The `x86_64` packages are built on an Intel NUC5PPYH (N3700 + 8G).

Both of the builders fetch config update (i.e. change to **this** repo) from my local git server instead of Github. 

In most cases changes are pushed to the local server first before they reach GitHub. Changes that reach GitHub first (e.g.by other contributors, or via PR) would need to be verified by myself before they reach the local git server and the builders.

## Contribution
### Package guideline
Keep in mind all of the packages need to be built on limited resource as listed in [the previous section](#build-infrastructure). And adding them to the repo is not a build-once-use-forever affair, they **need to be re-built on every update of the package itself, its sources, and any of the dependencies**. This project, like all my other projects, run without sponsorship. So, **I don't want to accept packages that's not absolutely needed**. 

Packages meeting the following conditions **won't be accepted**:
  - Already maintained in a repo, especially already maintained in a distro's official repo
  - Not verified to work on actual hardware
  - Take too much time to build

### Adding package
Create a PR which modifies `aarch64.yaml` and/or `x86_64.yaml`.

## License

The repo config, document, and wrapper scripts, i.e. all files living in this git repository, are licensed under AGPLv3

The builder which lives in [another repo](https://github.com/7Ji/arch_repo_builder) is licensed under Apache 2.0 + MIT dual license just like most of the other Rust projects. 

The PKGBUILDs used to create the packages each has their own licensing, and the sources are not maintained here.

The released packages follow the same license as their upstream, and the sources are not maintained here.