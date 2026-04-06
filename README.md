# qs-hyprview

This repo is my tablet-focused fork of `qs-hyprview`.

I use it as the overview window for my Hyprland setup. It is started by a user service and opened from a Hyprgrass touch gesture.

## What is different in this fork

- built for touch use first
- works with keyboard and touch input
- tuned for my Surface workflow, not as a general upstream replacement
- opened through `quickshell ipc` from Hyprland

If you want the original project, use upstream:

- https://github.com/dom0/qs-hyprview

## How it is started

This repo is launched by the user service:

- `~/.config/systemd/user/qs-hyprview.service`

The same repo path must also be used in your Hyprland config, because the touch gesture calls Quickshell directly:

```bash
quickshell ipc -p <path-to-this-repo> call expose open smartgrid
```

## Setup

1. Clone this repo anywhere.
2. Put the correct absolute path in `~/.config/systemd/user/qs-hyprview.service`.
3. Put the same path in your Hyprland config anywhere you call `quickshell ipc -p ...`.
4. Reload the user service and Hyprland:

```bash
systemctl --user daemon-reload
systemctl --user enable --now qs-hyprview.service
hyprctl reload
```

## IPC commands

The `expose` target supports:

- `toggle`
- `open`
- `close`

Examples:

```bash
quickshell ipc -p <path-to-this-repo> call expose open smartgrid
quickshell ipc -p <path-to-this-repo> call expose close
```

## Notes

- This repo is meant to stay in sync with the `hyprland-surface` repo, especially for paths and startup behavior.
- The default `shell.qml` in this fork starts `Hyprview` with `liveCapture: false` and `moveCursorToActiveWindow: false`.
