# Wispr Flow for Linux — Arch Linux, CachyOS, Ubuntu, Fedora & Any Distro

[![Version](https://img.shields.io/badge/Wispr%20Flow-1.6.1483-blue)](https://github.com/mohammed160209/wispr-flow-linux/releases)
[![Helper](https://img.shields.io/badge/Rust%20Helper-v0.1.5-orange)](https://github.com/mohammed160209/wispr-flow-helper)
[![Audio](https://img.shields.io/badge/PipeWire-System%20Audio%20%2B%20Mic-success)](#pipewire-system-audio-capture-notetaker)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-lightgrey)](UNLICENSE)

A **maintained, full-featured Linux port of Wispr Flow** (`v1.6.1483`, matching the Windows upstream release) built for **Arch Linux, CachyOS, EndeavourOS, Ubuntu/Debian, Fedora**, and any modern Wayland or X11 Linux distribution.

Unlike basic Electron wrappers, this build pairs the patched Windows Wispr Flow app with a clean-room **Rust helper (`wispr-flow-linux-helper`)** that restores **PipeWire system audio capture for Notetaker meetings**, global push-to-talk shortcuts, virtual keyboard paste injection, and an **unclipped always-on-top floating Status pill**.

---

## One-Command Quick Install (Arch Linux / CachyOS / Ubuntu / Fedora)

Run this as your normal user (never with `sudo`—the script prompts `sudo` only if system packages or `/dev/uinput` rules need installation):

```bash
curl -fsSL https://raw.githubusercontent.com/mohammed160209/wispr-flow-linux/main/install.sh | bash
```

Or clone and inspect/run locally (or build cleanly from source):

```bash
git clone https://github.com/mohammed160209/wispr-flow-linux.git
cd wispr-flow-linux
./install.sh                # Fast install from verified GitHub Release
# OR: ./install.sh --from-source   # Compiles Rust helper + patches Windows installer locally
```

### What `install.sh` Sets Up Automatically
1. **Installs distro audio & Wayland clipboard dependencies** (`pipewire`, `pipewire-pulse`, `wl-clipboard`, `xclip`, `gtk3`, `nss`, `alsa-lib`).
2. **Downloads & SHA-256 verifies** the latest AppImage and extracts it statically under `~/.local/share/wispr-flow` (zero FUSE startup overhead).
3. **Installs `wispr-flow`** in `~/.local/bin/wispr-flow` and your desktop application menu, automatically enabling `WISPR_USE_X11=1` on GNOME Wayland so dynamic `XShape` pill bounds never clip or swallow background clicks.
4. **Configures `/dev/uinput` permissions** (`--install-udev-rules`) so global push-to-talk and text injection work seamlessly without root.
5. **Runs `wispr-flow --doctor`** and checks PipeWire so you know every component is green immediately.

> [!NOTE]
> **First-time GNOME Wayland users:** The helper automatically installs the **Wispr Flow Window Bridge** GNOME Shell extension (`wispr-flow-window-bridge@wispr.flow`). Log out and log back in **once** after initial installation so GNOME Shell loads the extension into Mutter.

---

## Key Features & Linux Parity

| Feature | Linux Implementation | Benefit |
| :--- | :--- | :--- |
| **Notetaker System Audio + Mic** | Native in-process PipeWire (`libpulse-simple.so.0`) `@DEFAULT_MONITOR@` streaming `16 kHz` mono `WAF2` frames in parallel with mic | Records both your voice and laptop/headphone/Bluetooth call audio with near-zero CPU/battery draw |
| **Notetaker Audio Input Selector** | Tray menu selector backed by `~/.config/Wispr Flow/notetaker-input-mode.json` | Switch live between **System + Mic (Both)**, **System Audio Only**, and **Microphone Only** |
| **Floating Status Pill & Animations** | Full `512×614` (`1184×1420` HiDPI) XWayland canvas + `6 px` padded `XShape` + `requestAnimationFrame` spring tracker | Click-through outside the pill; expanded banners, Command mode, and meeting pills never clip on edges |
| **Global Shortcuts & Text Injection** | In-process `/dev/uinput` virtual keyboard + `wl-clipboard` (Wayland) or `XTEST` + `xclip` (X11) | Push-to-talk, hold-to-talk, Command mode, and instant paste across terminals, browsers, and native apps |
| **GNOME & Dash to Dock Coexistence** | Bundled GNOME Shell 45–50+ bridge extension + `_NET_WM_WINDOW_TYPE`/`UTILITY` stacking up to `1600×1600` | Keeps pill above windows without triggering Dash to Dock intellihide jitter (`intellihide-ignore-wispr-overlay`) |
| **Windows Upstream Parity** | Pinned to official Windows **`1.6.1483`** installer with automated tripwire validation | Same UI, Notetaker workflows, connectors, and core app behavior as Windows/macOS |

---

## Architecture: How the 4 Layers Fit Together

A normal user only runs **Layer 4** (or [`install.sh`](install.sh)), because **Layers 2 and 3 are bundled inside the package**:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. Main Electron App & Packaging  (mohammed160209/wispr-flow-linux)     │
│    Unpacks Windows Wispr Flow 1.6.1483, injects Linux/Notetaker/pill    │
│    patches, embeds the helper binary, and packages AppImage / AUR / deb │
├─────────────────────────────────────────────────────────────────────────┤
│ 3. Native Rust Helper Binary      (mohammed160209/wispr-flow-helper)    │
│    Embedded at resources/Release/wispr-flow-linux-helper. Runs evdev    │
│    hotkeys, /dev/uinput typing, & PipeWire WAF2 system audio loopback.  │
├─────────────────────────────────────────────────────────────────────────┤
│ 2. GNOME Window Bridge Extension  (Auto-installed by Helper)            │
│    wispr-flow-window-bridge@wispr.flow — GNOME Wayland focus bridge,    │
│    pill always-on-top manager, and Alt-Tab / taskbar exclusion.         │
├─────────────────────────────────────────────────────────────────────────┤
│ 1. Linux OS Dependencies          (Installed by pacman / apt / dnf)     │
│    pipewire + pipewire-pulse · wl-clipboard / xclip · /dev/uinput rule  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## PipeWire System Audio Capture (Notetaker)

Upstream Notetaker relies on Windows' native WASAPI loopback binary protocol (`endpoint_opened` on `stderr`, followed by `1,304`-byte `WAF2` frames over `stdout`). On Linux:

- **Zero extra processes:** [`wispr-flow-helper`](https://github.com/mohammed160209/wispr-flow-helper/blob/main/src/system_audio.rs) loads `libpulse-simple.so.0` inside the helper process itself and captures PipeWire's `@DEFAULT_MONITOR@`.
- **Follows your active output automatically:** Whether meeting sound comes from laptop speakers, USB/3.5 mm headphones, HDMI, or Bluetooth earbuds, `@DEFAULT_MONITOR@` captures it seamlessly and auto-reconnects if you switch devices mid-call.
- **Live Tray Selector:** Right-click the **Wispr Flow system tray icon → Notetaker Audio Input**:
  - **System Audio + Microphone (Both)** *(default)*
  - **System Audio Only (Desktop Sound)** *(mutes mic PCM cleanly while keeping stream timing intact)*
  - **Microphone Only** *(zeros monitor frames in the helper)*

Verify PipeWire readiness anytime:

```bash
pactl info | grep -E "Server Name|Default Sink"
# Expected: Server Name: PulseAudio (on PipeWire 1.x.x)
```

---

## Distribution & Desktop Notes

### Arch Linux / CachyOS / EndeavourOS / Manjaro
- **Recommended:** Use [`./install.sh`](install.sh) above.
- **Manual AUR-style package build:** Customize and build via `makepkg` using [`scripts/aur/PKGBUILD.template`](scripts/aur/PKGBUILD.template), which extracts the AppImage under `/opt/wispr-flow-appimage`, installs all PipeWire dependencies (`pipewire`, `pipewire-pulse`, `libpulse`), and configures the GNOME `WISPR_USE_X11=1` launcher automatically.
- **If migrating from an older `wispr-flow-appimage` package (`1.6.1337`):** Remove the old system package first (`sudo pacman -R wispr-flow-appimage`) so `/usr/bin/wispr-flow` doesn't shadow `~/.local/bin/wispr-flow`.

### GNOME + Dash to Dock
- Running under XWayland (`WISPR_USE_X11=1`, handled automatically by [`install.sh`](install.sh)) allows Electron's native `setShape` to cut out everything outside the pill (`+6 px` padding) so clicks fall straight through to underlying windows without clipping wide pill states.
- If using Dash to Dock with intellihide, keep `intellihide-ignore-wispr-overlay` enabled (`true`) so the floating status pill never keeps the dock permanently raised or hidden incorrectly.

### Manual AppImage Download
Prebuilt verified AppImages (`wispr-flow-1.6.1483-1.0.5-x86_64.AppImage`) are available on the [Releases page](https://github.com/mohammed160209/wispr-flow-linux/releases):

```bash
chmod +x wispr-flow-1.6.1483-1.0.5-x86_64.AppImage
./wispr-flow-1.6.1483-1.0.5-x86_64.AppImage --install-udev-rules
WISPR_USE_X11=1 ./wispr-flow-1.6.1483-1.0.5-x86_64.AppImage --no-sandbox
```

---

## Building From Source & Maintaining Upstream Parity

By default, `build.sh` fetches the pinned official Windows Wispr Flow installer from [`scripts/setup/installer-pin.sh`](scripts/setup/installer-pin.sh), verifies its SHA-256 checksum, pulls the matching Rust helper binary from [`mohammed160209/wispr-flow-helper`](https://github.com/mohammed160209/wispr-flow-helper) (pinned in [`helper-version.txt`](helper-version.txt)), applies all 18 Linux patches, and produces `.AppImage`, `.deb`, or `.rpm` packages.

```bash
# Optional: compile helper from source first
git clone https://github.com/mohammed160209/wispr-flow-helper.git
(cd wispr-flow-helper && cargo build --release)

# Build Wispr Flow for Linux (auto-detects Arch/Debian/Fedora; passes -b appimage|deb|rpm)
git clone https://github.com/mohammed160209/wispr-flow-linux.git
cd wispr-flow-linux
HELPER_BIN="$PWD/../wispr-flow-helper/target/release/wispr-flow-linux-helper" \
  ./build.sh -b appimage
```

### Updating to a New Upstream Windows Version
1. Update the pinned Windows installer URL, version, and SHA-256 in [`scripts/setup/installer-pin.sh`](scripts/setup/installer-pin.sh) (or use [`scripts/setup/write-installer-pin.sh`](scripts/setup/write-installer-pin.sh)).
2. Verify all 37 upstream code tripwires, patch idempotency, JS syntax checks, and marker assertions:
   ```bash
   ./tests/test-patch-stage.sh
   ```
3. Rebuild and verify live diagnostics:
   ```bash
   ./build.sh -b appimage
   ./build-linux/appimage/wispr-flow-*.AppImage --doctor
   ```

---

## Troubleshooting & Uninstall

- **Run diagnostics first:**
  ```bash
  wispr-flow --doctor
  ```
  Checks display backend (`Wayland`/`XWayland`), `/dev/uinput` permissions, `wl-clipboard`/`xclip`, AT-SPI accessibility, `wispr-flow-window-bridge@wispr.flow` extension status, helper binary version, and recent `launcher.log` crashes.
- **Uninstall cleanly:**
  ```bash
  ./install.sh --uninstall
  ```
  *(Removes the app binary, desktop entries, and icons while preserving your login/settings in `~/.config/Wispr Flow`.)*

---

## License & Disclaimer

This is an unofficial community Linux port and clean-room native helper not affiliated with Wispr. The build scripts, Electron patches, installer, and Rust helper ([`wispr-flow-helper`](https://github.com/mohammed160209/wispr-flow-helper)) are released into the public domain under the [Unlicense](UNLICENSE). Upstream Wispr Flow assets fetched at build time remain proprietary and subject to Wispr's terms.
