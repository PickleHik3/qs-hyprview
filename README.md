# qs-hyprview

This repo is my tablet-focused fork of `qs-hyprview`.

It runs as a Quickshell overview for Hyprland and can be opened through `quickshell ipc`.

## What is different in this fork

- built for touch use first
- works with keyboard and touch input
- tuned for my Surface workflow, not as a general upstream replacement
- opened through `quickshell ipc` from Hyprland

If you want the original project, use upstream:

- https://github.com/dom0/qs-hyprview

## Installation

### 1. Clone the repo

Clone the repo into the default app path:

```bash
mkdir -p ~/.config/hypr/apps
cd ~/.config/hypr/apps
git clone https://github.com/PickleHik3/qs-hyprview
```

### 2. Install the user service

This repo ships the service file at:

- `systemd-user/qs-hyprview.service`

Install it with:

```bash
mkdir -p ~/.config/systemd/user
cp systemd-user/qs-hyprview.service ~/.config/systemd/user/qs-hyprview.service
```

### 3. Enable the service

```bash
systemctl --user daemon-reload
systemctl --user enable --now qs-hyprview.service
```

### 4. Add the IPC command to Hyprland

Use the same repo path in your Hyprland config anywhere you want to open the overview:

```bash
quickshell ipc -p $HOME/.config/hypr/apps/qs-hyprview call expose open smartgrid
```

Example Hyprgrass binding:

```ini
hyprgrass-bind = , edge:d:u, exec, quickshell ipc -p $HOME/.config/hypr/apps/qs-hyprview call expose open smartgrid
```

### 5. Reload Hyprland

```bash
hyprctl reload
```

### 6. Verify

Check that Quickshell is running:

```bash
systemctl --user status qs-hyprview.service --no-pager
```

Test the overview manually:

```bash
quickshell ipc -p $HOME/.config/hypr/apps/qs-hyprview call expose open smartgrid
quickshell ipc -p $HOME/.config/hypr/apps/qs-hyprview call expose close
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

- The default `shell.qml` in this fork starts `Hyprview` with `liveCapture: false` and `moveCursorToActiveWindow: false`.
