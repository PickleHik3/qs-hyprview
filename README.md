# qs-hyprview (tablet fork)

Lean Quickshell overview used by this setup.

This fork is intentionally tuned for one workflow:
- bottom-edge gesture opens overview via `quickshell ipc`
- keyboard + touch interaction
- performance-focused thumbnail behavior
- workspace strip + drop-to-move integration

This is not a feature mirror of upstream and is documented as local/fork behavior only.

## Runtime

Launch path is defined by your user service:
- `~/.config/systemd/user/qs-hyprview.service`

The same path must be used in Hyprland IPC binds:
- `quickshell ipc -p <path-to-qs-hyprview> call expose open smartgrid`

## Minimal integration

1. Clone this repo anywhere.
2. Set the absolute repo path in:
- `~/.config/systemd/user/qs-hyprview.service` (`ExecStart=... -p <repo-path>`)
- `~/.config/hypr/hyprland.conf` (`quickshell ipc -p <repo-path> ...`)
3. Reload services/config:

```bash
systemctl --user daemon-reload
systemctl --user enable --now qs-hyprview.service
hyprctl reload
```

## IPC

Available actions through target `expose`:
- `toggle`
- `open`
- `close`

Examples:

```bash
quickshell ipc -p <repo-path> call expose open smartgrid
quickshell ipc -p <repo-path> call expose close
```

## Notes

- Keep this repo and `hyprland-surface` README aligned when paths or startup behavior change.
- Upstream reference: https://github.com/dom0/qs-hyprview
