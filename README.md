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

Optionally, install my keyring (there's only one key so it's really not a ring)
```
pacman -Syu 7ji-keyring
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

#### Testing
In the PR, you **must** list the time used and whether you could build them using https://github.com/7Ji/arch_repo_builder with a minimal config. Testing the build using makepkg or makechrootpkg is not allowed. **PR that wants to add packages without correct testing is considered impossible to build and won't be accepted.**

E.g., if you want to add `devilutionx` and `fheroes2` to `aarch64`, create an empty folder, and create an `aarch64.yaml` with the following content:

```
pkgbuilds:
  devilutionx: AUR
  fheroes2: AUR
```
_The config syntax is documented [here](https://github.com/7Ji/arch_repo_builder#config)_

Create an `arch_repo_builder` repo in another persistent place if not yet:
```
git init arch_repo_builder
cd arch_repo_builder
git remote add origin https://github.com/7Ji/arch_repo_builder.git
git config remote.origin.fetch '+refs/heads/master:refs/remotes/origin/master'
```
Update the repo and build the builder itself:
```
git fetch --depth 1
git reset --hard origin/master
cargo build --release
ln -sf $(readlink -f target/release/arch_repo_builder) [path to your testing dir]/arch_repo_builder
```
Run builder against your minimal config to test:
```
sudo ./arch_repo_builder aarch64.yaml
```

