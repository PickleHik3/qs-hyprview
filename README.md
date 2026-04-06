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

Clone the repo anywhere you want to keep it:

```bash
git clone https://github.com/PickleHik3/qs-hyprview ~/qs-hyprview
```

You can use a different path, but use that same absolute path everywhere below.

### 2. Create the user service

Create `~/.config/systemd/user/qs-hyprview.service`:

```ini
[Unit]
Description=Quickshell Hyprview
PartOf=hyprland-session.target
After=hyprland-session.target

[Service]
Type=simple
ExecStart=/usr/bin/quickshell -p /home/your-user/qs-hyprview
Restart=on-failure
RestartSec=1

[Install]
WantedBy=hyprland-session.target
```

Replace `/home/your-user/qs-hyprview` with the real path to your clone.

### 3. Enable the service

```bash
systemctl --user daemon-reload
systemctl --user enable --now qs-hyprview.service
```

### 4. Add the IPC command to Hyprland

Use the same repo path in your Hyprland config anywhere you want to open the overview:

```bash
quickshell ipc -p /home/your-user/qs-hyprview call expose open smartgrid
```

Example Hyprgrass binding:

```ini
hyprgrass-bind = , edge:d:u, exec, quickshell ipc -p /home/your-user/qs-hyprview call expose open smartgrid
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
quickshell ipc -p /home/your-user/qs-hyprview call expose open smartgrid
quickshell ipc -p /home/your-user/qs-hyprview call expose close
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
