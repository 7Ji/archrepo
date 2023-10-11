# Systemd units to build and update repos daily and weekly

## Install the units
```
mkdir -p ~/.config/systemd/user/
ln -srf *.{service,timer} ~/.config/systemd/user/
```

## Enable the units
```
systemctl --user daemon-reload
systemctl --user enable --now repo-updater-{full,partial}.timer
```

## Trigger link

On Sunday: 
`repo-updater-full.timer` -> `repo-updater-full.service` -> `repo-builder.service`

On other week days: 
`repo-updater-partial.timer` -> `repo-updater-partial.service` -> `repo-builder.service`

## Journal
Whole log:
```
journalctl --user --unit repo-builder.service
```
Real time:
```
journalctl --user --unit repo-builder.service --follow
```