# Systemd units to build and update repos daily and weekly

## Install the units
```
sudo install -m 644 *.{service,timer} /etc/systemd/system/
```

## Set environment

Example content of `/etc/conf.d/repo.systemd.env`:
```
REPO_USER=nomad7ji
REPO_ARCH=aarch64
REPO_DROP=1000:998:nomad7ji
```

## Enable the units
```
sudo systemctl daemon-reload
sudo systemctl enable --now repo-updater-{full,partial}.timer
```

## Trigger link

On Sunday: 
`repo-updater-full.timer` -> `repo-updater-full.service` -> `repo-builder.service`

On other week days: 
`repo-updater-partial.timer` -> `repo-updater-partial.service` -> `repo-builder.service`

## Journal
Whole log:
```
journalctl -u repo-builder.service
```
Real time:
```
journalctl -u repo-builder.service --follow
```